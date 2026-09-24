# servermon: small Telegram server monitor (python stdlib only)
#
# Subcommands:
#   daemon          main loop: spool/outbox delivery, journal watcher, health,
#                   power and network checks, heartbeat + boot report
#   notify          enqueue a message into the incoming spool (works offline)
#   failure UNIT    enqueue a failure report for UNIT (servermon-failure@.service)
#   arr-check       poll Sonarr/Radarr queues for stuck imports (servermon-arr.service)
#   mark-shutdown   write the clean-shutdown marker (ExecStop of servermon-shutdown-marker)
#   status          print the current state
#
# Only the daemon touches state.db; every other producer drops a JSON file
# into <stateDir>/incoming/ which the daemon ingests.
#
# Test hooks (env):
#   SERVERMON_DRY_RUN=1        print messages instead of calling Telegram
#   SERVERMON_TEST_NET=<file>  file containing "up"/"down" replaces real network probes
#   SERVERMON_SYSFS=<dir>      alternative /sys root (power_supply, net)
#   SERVERMON_BOOT_ID / SERVERMON_BTIME   fake boot id / boot time
#   SERVERMON_SEND_DELAY       seconds between Telegram sends (default 1)

import argparse
import datetime
import html
import json
import logging
import os
import queue
import re
import signal
import socket
import sqlite3
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from collections import Counter, OrderedDict

LOG = logging.getLogger("servermon")

SEV_RANK = {"ok": 0, "info": 1, "warn": 2, "crit": 3}
SEV_ICON = {"ok": "✅", "info": "ℹ️", "warn": "\U0001f7e0", "crit": "\U0001f534"}
TG_LIMIT = 4096

DEFAULTS = {
    "hostname": socket.gethostname(),
    "stateDir": "/var/lib/servermon",
    "tokenFile": None,
    "chatIdFile": None,
    "apiBase": "https://api.telegram.org",
    "cooldown": 1800,
    "reminderInterval": 14400,
    "intervals": {"tick": 5, "heartbeat": 60, "heartbeatOnBattery": 15, "health": 300, "healthDelay": 60, "power": 5},
    "network": {
        "enable": True,
        "interval": 60,
        "offlineInterval": 30,
        "failThreshold": 3,
        "probeUrl": "https://api.telegram.org",
        "gateway": None,
        "interfaces": [],
        "digestThreshold": 8,
    },
    "mounts": [],
    "diskSpace": [],
    "power": {"enable": True, "ac": None, "battery": None, "lowBattery": [50, 25, 10, 5], "cooldown": 300},
    "journal": {"enable": True, "quiet": 20, "maxWindow": 180, "cooldown": 1800, "mountCooldown": 21600, "command": None},
    "arr": {"instances": [], "stuckAfter": 7200},
}


# ---------------------------------------------------------------- helpers

def now():
    return time.time()


def fmt_ts(ts):
    return datetime.datetime.fromtimestamp(ts).strftime("%Y-%m-%d %H:%M:%S")


def fmt_short(ts):
    # same day -> HH:MM:SS, else "Sep 20 19:07:11"
    d = datetime.datetime.fromtimestamp(ts)
    if d.date() == datetime.date.today():
        return d.strftime("%H:%M:%S")
    return d.strftime("%b %d %H:%M:%S")


def fmt_dur(sec):
    sec = int(max(0, sec))
    d, r = divmod(sec, 86400)
    h, r = divmod(r, 3600)
    m, s = divmod(r, 60)
    if d:
        return f"{d}d {h}h"
    if h:
        return f"{h}h {m}m"
    if m:
        return f"{m}m {s}s" if m < 10 else f"{m}m"
    return f"{s}s"


def deep_merge(base, over):
    out = dict(base)
    for k, v in (over or {}).items():
        if isinstance(v, dict) and isinstance(out.get(k), dict):
            out[k] = deep_merge(out[k], v)
        else:
            out[k] = v
    return out


def load_config(path):
    cfg = DEFAULTS
    path = path or os.environ.get("SERVERMON_CONFIG")
    if path:
        with open(path) as f:
            cfg = deep_merge(DEFAULTS, json.load(f))
    return cfg


def sysfs(p):
    return os.environ.get("SERVERMON_SYSFS", "/sys") + p


def read_file(path, default=None):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return default


def get_boot_id():
    return os.environ.get("SERVERMON_BOOT_ID") or read_file("/proc/sys/kernel/random/boot_id", "unknown")


def get_btime():
    if os.environ.get("SERVERMON_BTIME"):
        return float(os.environ["SERVERMON_BTIME"])
    for line in (read_file("/proc/stat", "") or "").splitlines():
        if line.startswith("btime "):
            return float(line.split()[1])
    return now()


def fsync_dir(d):
    try:
        fd = os.open(d, os.O_RDONLY)
        try:
            os.fsync(fd)
        finally:
            os.close(fd)
    except OSError:
        pass


def atomic_write_json(path, obj, mode=0o640):
    d = os.path.dirname(path)
    tmp = os.path.join(d, f".{os.path.basename(path)}.{os.getpid()}.tmp")
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, mode)
    try:
        os.write(fd, json.dumps(obj, indent=1).encode())
        os.fsync(fd)
    finally:
        os.close(fd)
    os.replace(tmp, path)
    fsync_dir(d)


def read_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def run(cmd, timeout=10):
    """Run a command with a hard timeout. A process stuck in D-state is abandoned."""
    try:
        p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.DEVNULL,
                             text=True, errors="replace", start_new_session=True)
    except OSError as e:
        return 127, "", str(e)
    try:
        out, err = p.communicate(timeout=timeout)
        return p.returncode, out, err
    except subprocess.TimeoutExpired:
        try:
            os.killpg(p.pid, signal.SIGKILL)
        except OSError:
            pass
        try:
            p.communicate(timeout=2)
        except subprocess.TimeoutExpired:
            pass
        return None, "", f"timed out after {timeout}s"


def system_stopping():
    """(stopping, kind) - is the whole system shutting down right now?"""
    kind = None
    rc, out, _ = run(["systemctl", "list-jobs", "--no-legend", "--no-pager"], timeout=4)
    if rc == 0:
        for k in ("reboot", "kexec", "poweroff", "halt"):
            if f"{k}.target" in out:
                kind = k
                break
    rc, out, _ = run(["systemctl", "is-system-running"], timeout=4)
    stopping = out.strip() == "stopping" or kind is not None
    if not stopping and rc is None and os.path.exists("/run/nologin"):
        stopping = True  # dbus gone: /run/nologin is created by systemd-user-sessions on shutdown
    return stopping, kind or ("shutdown" if stopping else None)


# ---------------------------------------------------------------- spool (producer side)

def incoming_dir(cfg):
    return os.path.join(cfg["stateDir"], "incoming")


def drop_incoming(cfg, obj):
    d = incoming_dir(cfg)
    obj.setdefault("created", now())
    name = f"{time.time_ns()}-{os.getpid()}-{os.urandom(3).hex()}.json"
    tmp = os.path.join(d, "." + name)
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o644)
    try:
        os.fchmod(fd, 0o644)  # daemon (another user) must be able to read it
        os.write(fd, json.dumps(obj).encode())
        os.fsync(fd)
    finally:
        os.close(fd)
    os.rename(tmp, os.path.join(d, name))
    fsync_dir(d)


# ---------------------------------------------------------------- state store (daemon only)

SCHEMA = """
CREATE TABLE IF NOT EXISTS outbox(
  id INTEGER PRIMARY KEY AUTOINCREMENT, created REAL, key TEXT, severity TEXT,
  title TEXT, body TEXT, pre TEXT, priority INTEGER DEFAULT 0,
  attempts INTEGER DEFAULT 0, next_try REAL DEFAULT 0, last_error TEXT);
CREATE TABLE IF NOT EXISTS sent(id INTEGER PRIMARY KEY, created REAL, sent REAL, key TEXT, title TEXT);
CREATE TABLE IF NOT EXISTS ratelimit(key TEXT PRIMARY KEY, last_sent REAL, cooldown REAL,
  suppressed INTEGER DEFAULT 0, first_suppressed REAL, last_title TEXT, severity TEXT);
CREATE TABLE IF NOT EXISTS kv(k TEXT PRIMARY KEY, v TEXT);
CREATE TABLE IF NOT EXISTS events(id INTEGER PRIMARY KEY AUTOINCREMENT, ts REAL, boot_id TEXT, kind TEXT, data TEXT);
CREATE INDEX IF NOT EXISTS events_boot ON events(boot_id, ts);
"""


class Store:
    def __init__(self, path, boot_id):
        self.db = sqlite3.connect(path, timeout=30, isolation_level=None)
        self.db.row_factory = sqlite3.Row
        self.db.execute("PRAGMA journal_mode=WAL")
        self.db.execute("PRAGMA synchronous=FULL")
        self.db.executescript(SCHEMA)
        self.boot_id = boot_id

    def kv_get(self, k, default=None):
        r = self.db.execute("SELECT v FROM kv WHERE k=?", (k,)).fetchone()
        return json.loads(r[0]) if r else default

    def kv_set(self, k, v):
        self.db.execute("INSERT OR REPLACE INTO kv(k,v) VALUES(?,?)", (k, json.dumps(v)))

    def event(self, kind, data=None, ts=None):
        self.db.execute("INSERT INTO events(ts,boot_id,kind,data) VALUES(?,?,?,?)",
                        (ts or now(), self.boot_id, kind, json.dumps(data or {})))
        # keep the table small
        self.db.execute("DELETE FROM events WHERE ts < ?", (now() - 90 * 86400,))

    def events(self, boot_id=None, kinds=None, since=None, until=None):
        q, a = "SELECT ts,boot_id,kind,data FROM events WHERE 1=1", []
        if boot_id:
            q += " AND boot_id=?"
            a.append(boot_id)
        if since is not None:
            q += " AND ts>=?"
            a.append(since)
        if until is not None:
            q += " AND ts<=?"
            a.append(until)
        rows = self.db.execute(q + " ORDER BY ts, id", a).fetchall()
        return [(r[0], r[1], r[2], json.loads(r[3])) for r in rows if not kinds or r[2] in kinds]

    def enqueue(self, created, key, severity, title, body, pre, priority=0):
        self.db.execute("INSERT INTO outbox(created,key,severity,title,body,pre,priority) VALUES(?,?,?,?,?,?,?)",
                        (created, key, severity, title, body or "", pre or "", priority))

    def pending(self, t=None):
        return self.db.execute(
            "SELECT * FROM outbox WHERE next_try<=? ORDER BY priority DESC, created, id", (t or now(),)).fetchall()

    def pending_count(self, since=None):
        if since is None:
            return self.db.execute("SELECT COUNT(*) FROM outbox").fetchone()[0]
        return self.db.execute("SELECT COUNT(*) FROM outbox WHERE created>=?", (since,)).fetchone()[0]

    def mark_sent(self, ids):
        t = now()
        for i in ids:
            r = self.db.execute("SELECT created,key,title FROM outbox WHERE id=?", (i,)).fetchone()
            if r:
                self.db.execute("INSERT INTO sent(created,sent,key,title) VALUES(?,?,?,?)", (r[0], t, r[1], r[2]))
            self.db.execute("DELETE FROM outbox WHERE id=?", (i,))
        self.db.execute("DELETE FROM sent WHERE id NOT IN (SELECT id FROM sent ORDER BY id DESC LIMIT 1000)")

    def defer(self, i, delay, err):
        self.db.execute("UPDATE outbox SET attempts=attempts+1, next_try=?, last_error=? WHERE id=?",
                        (now() + delay, str(err)[:300], i))


# ---------------------------------------------------------------- telegram

def esc(s):
    return html.escape(s or "", quote=False)


def cut(s, n):
    s = s or ""
    return s if len(s) <= n else s[: n - 20] + "\n…(truncated)"


def render(cfg, row, t):
    """HTML message for one outbox row."""
    icon = SEV_ICON.get(row["severity"], "")
    head = f"{icon} <b>{esc(cfg['hostname'])}</b> · <b>{esc(row['title'])}</b>"
    late = t - row["created"]
    foot = f"<i>{fmt_ts(row['created'])}"
    if late > 120:
        foot += f" · delivered {fmt_dur(late)} late"
    foot += "</i>"
    body, pre = row["body"] or "", row["pre"] or ""
    for blim, plim in ((2600, 1200), (1800, 600), (1200, 0)):
        parts = [head]
        if body:
            parts.append(esc(cut(body, blim)))
        if pre and plim:
            parts.append("<pre>" + esc(cut(pre, plim)) + "</pre>")
        parts.append(foot)
        text = "\n".join(parts)
        if len(text) <= TG_LIMIT:
            return text
    return text[:TG_LIMIT]


def strip_html(text):
    return html.unescape(re.sub(r"</?(b|i|pre|code)>", "", text))


class Telegram:
    def __init__(self, cfg):
        self.cfg = cfg
        self.dry = os.environ.get("SERVERMON_DRY_RUN") == "1"
        self.test_net = os.environ.get("SERVERMON_TEST_NET")

    def credentials(self):
        if self.dry:
            return "dry", "dry"
        tok = read_file(self.cfg["tokenFile"]) if self.cfg.get("tokenFile") else None
        chat = read_file(self.cfg["chatIdFile"]) if self.cfg.get("chatIdFile") else None
        return tok, chat

    def send(self, text, html_mode=True):
        """-> (status, retry_after). status: ok | net | retry | bad | auth | noconf"""
        if self.test_net and (read_file(self.test_net, "up") or "up") != "up":
            return "net", 0
        if self.dry:
            print("===== TELEGRAM (dry-run) =====\n" + strip_html(text) + "\n", flush=True)
            return "ok", 0
        tok, chat = self.credentials()
        if not tok or not chat:
            return "noconf", 0
        data = {"chat_id": chat, "text": text, "disable_web_page_preview": "true"}
        if html_mode:
            data["parse_mode"] = "HTML"
        req = urllib.request.Request(f"{self.cfg['apiBase']}/bot{tok}/sendMessage",
                                     data=urllib.parse.urlencode(data).encode())
        try:
            with urllib.request.urlopen(req, timeout=15) as r:
                r.read()
            return "ok", 0
        except urllib.error.HTTPError as e:
            try:
                j = json.loads(e.read().decode())
            except ValueError:
                j = {}
            desc = j.get("description", str(e))
            if e.code == 429:
                return "retry", int(j.get("parameters", {}).get("retry_after", 30))
            if e.code in (401, 403, 404):
                LOG.error("telegram rejected credentials: %s", desc)
                return "auth", 600
            if e.code == 400:
                LOG.warning("telegram bad request: %s", desc)
                return "bad", 0
            return "retry", 60
        except (urllib.error.URLError, OSError) as e:
            LOG.info("telegram unreachable: %s", e)
            return "net", 0


# ---------------------------------------------------------------- mounts / sysfs

def unescape_mount(s):
    return re.sub(r"\\([0-7]{3})", lambda m: chr(int(m.group(1), 8)), s)


def read_mountinfo():
    out = []
    for line in (read_file("/proc/self/mountinfo", "") or "").splitlines():
        p = line.split()
        try:
            sep = p.index("-")
        except ValueError:
            continue
        out.append({
            "majmin": p[2], "target": unescape_mount(p[4]), "opts": p[5].split(","),
            "fstype": p[sep + 1], "source": unescape_mount(p[sep + 2]),
            "super": p[sep + 3].split(",") if len(p) > sep + 3 else [],
        })
    return out


def mount_for(target, mi=None):
    """Top-most real (non-autofs) mount at target."""
    cand = [m for m in (mi or read_mountinfo()) if m["target"] == target and m["fstype"] != "autofs"]
    return cand[-1] if cand else None


def mounts_of_dev(dev, mi=None):
    """Mount points whose source is /dev/<dev> (or a partition of it)."""
    res = []
    for m in mi or read_mountinfo():
        src = os.path.basename(m["source"])
        if m["source"].startswith("/dev/") and (src == dev or re.fullmatch(re.escape(dev) + r"p?\d+", src)):
            res.append(m["target"])
    return sorted(set(res))


def usb_storage_map():
    """{usb_port: {dev, model}} for block devices behind USB (e.g. 2-1.2 -> sdd)."""
    res = {}
    base = sysfs("/block")
    try:
        names = os.listdir(base)
    except OSError:
        return res
    for n in names:
        if not n.startswith("sd"):
            continue
        path = os.path.realpath(os.path.join(base, n))
        m = re.findall(r"/(\d+-\d+(?:\.\d+)*)/(?=\1:)", path)
        if not m:
            continue
        vendor = read_file(os.path.join(base, n, "device/vendor"), "") or ""
        model = read_file(os.path.join(base, n, "device/model"), "") or ""
        res[m[-1]] = {"dev": n, "model": f"{vendor} {model}".strip()}
    return res


def default_gateway():
    for line in (read_file("/proc/net/route", "") or "").splitlines()[1:]:
        p = line.split()
        if len(p) > 3 and p[1] == "00000000" and int(p[3], 16) & 2:
            gw = socket.inet_ntoa(bytes.fromhex(p[2])[::-1])
            return p[0], gw
    return None, None


# ---------------------------------------------------------------- journal classification

R = re.compile
KERNEL_RULES = [
    # (regex, bucket, kind, strong, severity)
    (R(r"^usb (\d+-[\d.]+): USB disconnect, device number (\d+)"), "storage", "usb_disconnect", None, "warn"),
    (R(r"^usb (\d+-[\d.]+): new \S+ USB device number \d+ using (\S+)"), "storage", "usb_new", False, "info"),
    (R(r"^usb (\d+-[\d.]+): Product: (.+)$"), "storage", "usb_product", False, "info"),
    (R(r"^usb (\d+-[\d.]+): reset \S+ USB device number"), "storage", "usb_reset", None, "warn"),
    (R(r"^sd \S+: \[(sd[a-z]+)\] Attached SCSI"), "storage", "attached", False, "info"),
    (R(r"^sd \S+: \[(sd[a-z]+)\] Synchronize Cache.*failed"), "storage", "sync_fail", True, "warn"),
    (R(r"device offline error, dev (\w+), sector (\d+)"), "storage", "offline", True, "crit"),
    (R(r"(?:I/O|critical \w+) error, dev (\w+), sector (\d+)"), "storage", "ioerr", True, "crit"),
    (R(r"^Buffer I/O error on dev(?:ice)? (\w+), logical block (\d+)"), "storage", "bufio", True, "crit"),
    (R(r"^EXT4-fs error \(device (\w+)\): (\w+)"), "storage", "ext4_error", True, "crit"),
    (R(r"^EXT4-fs warning \(device (\w+)\): (\w+):\d+: .*(?:error|I/O)"), "storage", "ext4_warn", True, "warn"),
    (R(r"^EXT4-fs \((\w+)\): .*potential data loss"), "storage", "dataloss", True, "crit"),
    (R(r"^EXT4-fs \((\w+)\): shut down requested"), "storage", "shutdown", True, "crit"),
    (R(r"^EXT4-fs \((\w+)\): Remounting filesystem read-only"), "storage", "readonly", True, "crit"),
    (R(r"^Aborting journal on device (\w+?)(?:-\d+)?\.?$"), "storage", "jabort", True, "crit"),
    (R(r"^JBD2: .*error.*? (\w+?)(?:-\d+)?\.?$"), "storage", "jbd2", True, "crit"),
    (R(r"^EXT4-fs \((\w+)\): mounted filesystem"), "storage", "mounted", False, "info"),
    (R(r"(?:^|\s)(\w+): Link is (Up|Down)(?: - (.*))?$"), "netlink", "link", True, "warn"),
]
SYSTEMD_RULES = [
    (R(r"^Timed out waiting for device (\S+?)\.?$"), "mount", "dev_timeout", True, "warn"),
    (R(r"^Dependency failed for (/\S*?)\.?$"), "mount", "dep_failed", True, "warn"),
    (R(r"^Failed to mount (/\S*?)\.?$"), "mount", "mount_failed", True, "warn"),
    (R(r"^Failed unmounting (/\S*?)\.?$"), "storage", "umount_failed", True, "warn"),
]
STORAGE_TAGS = [  # kind -> short tag for titles, in order of importance
    ("dataloss", "POTENTIAL DATA LOSS"), ("shutdown", "fs shut down"), ("jabort", "journal aborted"),
    ("readonly", "remounted read-only"), ("ext4_error", "EXT4 errors"), ("usb_disconnect", "USB disconnect"),
    ("offline", "device offline"), ("ioerr", "I/O errors"), ("bufio", "I/O errors"), ("ext4_warn", "I/O errors"),
    ("jbd2", "journal errors"), ("umount_failed", "unmount failed"), ("usb_reset", "USB resets"),
    ("sync_fail", "cache flush failed"),
]


class Bucket:
    def __init__(self, key, ts):
        self.key, self.first, self.last, self.wall = key, ts, ts, now()
        self.lines = []  # (ts, kind, groups, msg, strong, sev)

    def add(self, ts, kind, groups, msg, strong, sev):
        self.last, self.wall = max(self.last, ts), now()
        self.lines.append((ts, kind, groups, msg, strong, sev))


class JournalWatcher:
    EOF = object()

    def __init__(self, mon):
        self.mon, self.cfg = mon, mon.cfg["journal"]
        self.q = queue.Queue(maxsize=20000)
        self.buckets = OrderedDict()
        self.proc = None
        self.read_cursor = None
        self.eof = False
        self.ignored = set()
        for m in mon.cfg["mounts"]:
            if not m.get("required", True) and not m.get("alertJournal", False):
                self.ignored.add(m["path"])
                if m.get("uuid"):
                    self.ignored.add(m["uuid"])

    # -- reader thread
    def start(self):
        threading.Thread(target=self._reader, daemon=True, name="journal").start()

    def _cmd(self):
        if self.cfg.get("command"):
            return list(self.cfg["command"])
        cmd = ["journalctl", "-f", "-o", "json", "--no-pager"]
        saved = self.mon.store_cursor
        if self.read_cursor:
            cmd += ["--after-cursor", self.read_cursor]
        elif saved and saved.get("boot") == self.mon.boot_id:
            cmd += ["--after-cursor", saved["cursor"]]
        else:
            cmd += ["-b", "--no-tail"]  # new boot: read it from the start (boot-time kernel errors)
        return cmd + ["_TRANSPORT=kernel", "+", "_PID=1"]

    def _reader(self):
        while not self.mon.stop_evt.is_set():
            cmd = self._cmd()
            LOG.info("journal: %s", " ".join(cmd))
            try:
                self.proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stdin=subprocess.DEVNULL,
                                             text=True, errors="replace")
                for line in self.proc.stdout:
                    try:
                        e = json.loads(line)
                    except ValueError:
                        continue
                    msg = e.get("MESSAGE")
                    if isinstance(msg, list):
                        msg = bytes(msg).decode("utf-8", "replace")
                    if not isinstance(msg, str):
                        continue
                    ts = int(e.get("__REALTIME_TIMESTAMP", time.time() * 1e6)) / 1e6
                    self.read_cursor = e.get("__CURSOR") or self.read_cursor
                    self.q.put((ts, e.get("_TRANSPORT"), str(e.get("_PID", "")), msg.strip(), self.read_cursor))
                self.proc.wait()
            except OSError as e:
                LOG.error("journal reader failed: %s", e)
            if self.cfg.get("command"):
                self.q.put(self.EOF)
                return
            self.mon.stop_evt.wait(5)

    def stop(self):
        if self.proc and self.proc.poll() is None:
            self.proc.terminate()

    # -- main thread
    def classify(self, transport, pid, msg):
        rules = KERNEL_RULES if transport == "kernel" else SYSTEMD_RULES if pid == "1" else ()
        for rx, bucket, kind, strong, sev in rules:
            m = rx.search(msg)
            if m:
                return bucket, kind, m.groups(), strong, sev
        return None

    def process(self, budget=5000):
        n = 0
        while n < budget:
            try:
                item = self.q.get_nowait()
            except queue.Empty:
                break
            n += 1
            if item is self.EOF:
                self.eof = True
                self.flush(force=True)
                continue
            ts, transport, pid, msg, cursor = item
            c = self.classify(transport, pid, msg)
            if c:
                self.handle(ts, msg, *c)
            if not self.buckets and cursor:
                # only persist the cursor when no incident is half-collected
                self.mon.save_cursor(cursor)
        return n

    def handle(self, ts, msg, bucket, kind, groups, strong, sev):
        if bucket == "netlink":
            iface = groups[0]
            ifaces = self.mon.cfg["network"]["interfaces"]
            if (ifaces and iface not in ifaces) or iface in ("lo",) or iface.startswith(("tailscale", "veth", "docker")):
                return
            self.mon.store.event("link", {"iface": iface, "state": groups[1], "info": groups[2]}, ts)
            key = f"netlink:{iface}"
        elif bucket == "mount":
            what = groups[0]
            path = self.mon.path_for_device(what) or what
            if path in self.ignored or any(u in what for u in self.ignored):
                return
            key = f"mount:{path}"
        else:
            key = "storage"
            if kind == "usb_disconnect":  # remember what was behind the port *before* it re-enumerates
                groups = groups + (dict(self.mon.usbmap.get(groups[0], {})),)
        b = self.buckets.get(key)
        q, mx = self.cfg["quiet"], self.cfg["maxWindow"]
        if bucket == "netlink":
            q = max(q, 60)  # group link flaps into one message
        if b and (ts - b.last > q or ts - b.first > mx):
            self.flush_one(key)
            b = None
        if not b:
            b = self.buckets[key] = Bucket(key, ts)
        b.add(ts, kind, groups, msg, strong, sev)

    def flush(self, force=False):
        t = now()
        for key in list(self.buckets):
            q = max(self.cfg["quiet"], 60) if key.startswith("netlink:") else self.cfg["quiet"]
            if force or t - self.buckets[key].wall > q:
                self.flush_one(key)

    def flush_one(self, key):
        b = self.buckets.pop(key)
        try:
            if key == "storage":
                self.summarize_storage(b)
            elif key.startswith("netlink:"):
                self.summarize_link(b, key.split(":", 1)[1])
            else:
                self.summarize_mount(b, key.split(":", 1)[1])
        except Exception:  # never let a formatting bug kill the daemon
            LOG.exception("failed to summarize incident %s", key)

    def summarize_storage(self, b):
        usbmap = self.mon.usbmap
        strong = False
        ports, fs, disks, attached, mounted, umount = {}, {}, {}, [], [], []
        samples, seen = [], set()
        sev = "info"
        kinds = Counter()
        for ts, kind, g, msg, st, s in b.lines:
            if kind in ("usb_disconnect", "usb_reset", "usb_new", "usb_product"):
                port = g[0]
                known = port in usbmap
                p = ports.setdefault(port, {"disc": [], "new": [], "reset": 0, "product": None})
                if kind == "usb_disconnect":
                    p["disc"].append(ts)
                    p["was"] = p.get("was") or (g[2] if len(g) > 2 and g[2] else None)
                elif kind == "usb_new":
                    p["new"].append(ts)
                elif kind == "usb_reset":
                    p["reset"] += 1
                else:
                    p["product"] = g[1]
                st = known if st is None else st
            elif kind in ("offline", "ioerr", "sync_fail"):
                disks.setdefault(g[0], Counter())[kind] += 1
                op = re.search(r"\((READ|WRITE)\)", msg)
                if op:
                    disks[g[0]][op.group(1)] += 1
            elif kind == "attached":
                attached.append(g[0])
            elif kind == "mounted":
                mounted.append(g[0])
            elif kind == "umount_failed":
                umount.append(g[0])
            else:
                f = fs.setdefault(g[0], {"k": Counter(), "inodes": [], "funcs": Counter()})
                f["k"][kind] += 1
                if kind in ("ext4_warn", "ext4_error"):
                    f["funcs"][g[1]] += 1
                for ino in re.findall(r"inode #?(\d+)", msg):
                    if ino not in f["inodes"]:
                        f["inodes"].append(ino)
            if st:
                strong = True
                kinds[kind] += 1
                if SEV_RANK[s] > SEV_RANK[sev]:
                    sev = s
            norm = re.sub(r"\d+", "N", msg)
            if st and norm not in seen and len(samples) < 8:
                seen.add(norm)
                samples.append(f"{fmt_short(ts)} {msg}")
        if not strong:
            return  # e.g. a USB stick plugged in, or disks attached at boot
        mi = read_mountinfo()
        lines = [f"Window: {fmt_short(b.first)} – {fmt_short(b.last)} ({fmt_dur(b.last - b.first)}, "
                 f"{len(b.lines)} kernel/systemd lines)"]
        devs = set()
        for port, p in ports.items():
            if port not in usbmap and not p.get("was"):
                continue  # not a storage device (keyboard dongle etc.)
            info = p.get("was") or usbmap.get(port, {})
            name = p["product"] or info.get("model") or "USB device"
            was = f", was {info['dev']}" if info.get("dev") else ""
            parts = []
            if p["disc"]:
                parts.append(f"disconnected at {fmt_short(p['disc'][0])}" + (f" ({len(p['disc'])}x)" if len(p["disc"]) > 1 else ""))
            if p["new"]:
                parts.append(f"re-enumerated at {fmt_short(p['new'][-1])}")
            if p["reset"]:
                parts.append(f"{p['reset']} bus resets")
            lines.append(f"• USB {port} ({name}{was}): " + ", ".join(parts))
            if info.get("dev"):
                devs.add(info["dev"])
        for d, c in disks.items():
            devs.add(d)
            det = ", ".join(f"{k} {v}" for k, v in (("READ", c["READ"]), ("WRITE", c["WRITE"])) if v)
            what = [t for k, t in (("offline", "device-offline"), ("ioerr", "I/O errors")) if c[k]]
            lines.append(f"• {d}: " + ", ".join(f"{c[k]} {t}" for k, t in (("offline", "device-offline"), ("ioerr", "I/O errors")) if c[k])
                         + (f" ({det})" if det and what else "") + ("; cache flush failed" if c["sync_fail"] else ""))
        for d, f in fs.items():
            devs.add(d)
            mp = mounts_of_dev(d, mi)
            flags = [t for k, t in (("jabort", "JOURNAL ABORTED"), ("jbd2", "journal I/O error"), ("shutdown", "FS SHUT DOWN"),
                                    ("readonly", "READ-ONLY"), ("dataloss", "POTENTIAL DATA LOSS")) if f["k"][k]]
            lines.append(f"• {d}" + (f" ({', '.join(mp)})" if mp else "") + (": " + ", ".join(flags) if flags else ":"))
            cnt = []
            if f["funcs"]:
                cnt.append("EXT4 " + ", ".join(f"{fn} x{n}" for fn, n in f["funcs"].most_common(4)))
            if f["k"]["bufio"]:
                cnt.append(f"Buffer I/O errors x{f['k']['bufio']}")
            if cnt:
                lines.append("   " + "; ".join(cnt))
            if f["inodes"]:
                ino = f["inodes"][:8]
                lines.append(f"   inodes: {', '.join(ino)}" + (f" (+{len(f['inodes']) - 8})" if len(f["inodes"]) > 8 else "")
                             + (f"  → find {mp[0]} -xdev -inum {ino[0]}" if mp else ""))
        if attached:
            lines.append(f"• attached: {', '.join(sorted(set(attached)))}")
        if mounted:
            lines.append(f"• mounted fs: {', '.join(sorted(set(mounted)))}")
        for u in umount:
            lines.append(f"• systemd failed to unmount {u} (busy → old mount stays, possibly dead)")
        links = self.mon.store.events(kinds=("link",), since=b.first - 15, until=b.first + 15)
        if links and (kinds["usb_disconnect"] or kinds["offline"]):
            lines.append("• NIC link changes at the same time (" + ", ".join(
                f"{d['iface']} {d['state']} {fmt_short(ts)}" for ts, _, _, d in links[:4]) + ") → possible power blip")
        if kinds["shutdown"] or kinds["jabort"] or kinds["umount_failed"]:
            lines.append("Hint: the mount is probably stale; check `findmnt -o TARGET,SOURCE,OPTIONS /mnt/media/*`, "
                         "stop the users, `umount -l` and remount.")
        tags = []
        for k, t in STORAGE_TAGS:
            if kinds[k] and t not in tags:
                tags.append(t)
        title = "Storage: " + ", ".join(tags[:3]) + (f" ({', '.join(sorted(devs))})" if devs else "")
        key = "storage:" + ",".join(sorted(devs)) + ":" + ",".join(sorted(tags))
        self.mon.alert(title, "\n".join(lines), sev, key=key, pre="\n".join(samples),
                       cooldown=self.cfg["cooldown"], created=b.first)

    def summarize_link(self, b, iface):
        seq = [(ts, g[1], g[2]) for ts, _, g, _, _, _ in b.lines]
        downs = sum(1 for _, s, _ in seq if s == "Down")
        final = seq[-1]
        steps = " → ".join(f"{s} {fmt_short(ts)}" + (f" ({i})" if i and s == "Up" else "") for ts, s, i in seq[:10])
        if len(seq) > 10:
            steps += f" … ({len(seq)} changes)"
        if final[1] == "Down":
            title, sev = f"NIC {iface} link DOWN", "crit"
        elif downs > 1:
            title, sev = f"NIC {iface} link flapping ({downs}x down)", "warn"
        else:
            title, sev = f"NIC {iface} link bounced", "warn"
        body = f"{steps}\nNow: {final[1]}" + (f" {final[2]}" if final[2] else "")
        self.mon.alert(title, body, sev, key=f"netlink:{iface}:{final[1]}", cooldown=self.cfg["cooldown"], created=b.first)

    def summarize_mount(self, b, path):
        c = Counter(kind for _, kind, _, _, _, _ in b.lines)
        what = {"dev_timeout": "timed out waiting for device", "dep_failed": "dependency failed",
                "mount_failed": "mount failed"}
        devs = sorted({g[0] for _, kind, g, _, _, _ in b.lines if kind == "dev_timeout"})
        body = f"{fmt_short(b.first)} – {fmt_short(b.last)}: " + ", ".join(f"{what[k]} x{n}" for k, n in c.items())
        if devs:
            body += "\nDevice: " + ", ".join(devs)
        body += "\n(Something keeps accessing this automount while the disk is missing.)"
        self.mon.alert(f"Mount failing: {path}", body, "warn", key=f"mountjob:{path}",
                       cooldown=self.cfg["mountCooldown"], created=b.first)


# ---------------------------------------------------------------- network

class Network:
    def __init__(self, mon):
        self.mon, self.cfg = mon, mon.cfg["network"]
        self.st = mon.store.kv_get("net", {"state": "unknown", "since": now(), "fails": 0,
                                           "first_fail": None, "cause": None, "boots": []})
        self.next_probe = now() + 1
        self.test = os.environ.get("SERVERMON_TEST_NET")

    def save(self):
        self.mon.store.kv_set("net", self.st)

    @property
    def state(self):
        return self.st["state"]

    def link_state(self):
        res = {}
        for i in self.cfg["interfaces"]:
            res[i] = read_file(sysfs(f"/class/net/{i}/carrier"), "0") == "1"
        return res

    def probe(self):
        if self.test:
            ok = (read_file(self.test, "up") or "up") == "up"
            return (self.success() if ok else self.failure("test: network down"))
        links = self.link_state()
        inet_ok = self.http_ok()
        if inet_ok:
            return self.success()
        iface, gw = default_gateway()
        gw = self.cfg.get("gateway") or gw
        if links and not any(links.values()):
            cause = "link down on " + ", ".join(links)
        elif not gw:
            cause = "no default route"
        elif not self.ping(gw):
            cause = f"gateway {gw} unreachable"
        else:
            cause = f"internet/Telegram unreachable (gateway {gw} OK)"
        return self.failure(cause)

    def http_ok(self):
        try:
            with urllib.request.urlopen(urllib.request.Request(self.cfg["probeUrl"], method="HEAD"), timeout=8):
                return True
        except urllib.error.HTTPError:
            return True  # got an HTTP answer: reachable
        except (urllib.error.URLError, OSError):
            return False

    def ping(self, host):
        rc, _, _ = run(["ping", "-c", "1", "-W", "2", host], timeout=5)
        return rc == 0

    def due(self):
        return self.cfg["enable"] and now() >= self.next_probe

    def schedule(self):
        bad = self.st["state"] == "offline" or self.st["fails"] > 0
        self.next_probe = now() + (self.cfg["offlineInterval"] if bad else self.cfg["interval"])

    def success(self):
        t = now()
        if self.st["state"] == "offline":
            self.recovered(t)
        elif self.st["state"] != "online":
            self.st.update(state="online", since=t)
            LOG.info("network online")
        self.st.update(fails=0, first_fail=None)
        self.save()
        self.schedule()

    def failure(self, cause):
        t = now()
        self.st["fails"] += 1
        self.st["first_fail"] = self.st.get("first_fail") or t
        self.st["last_cause"] = cause
        if self.st["state"] != "offline" and self.st["fails"] >= self.cfg["failThreshold"]:
            since = self.st["first_fail"]
            self.st.update(state="offline", since=since, cause=cause, boots=[])
            self.mon.store.event("net_down", {"cause": cause}, since)
            LOG.warning("network OFFLINE since %s: %s", fmt_ts(since), cause)
        self.save()
        self.schedule()

    def recovered(self, t):
        since = self.st["since"]
        spooled = self.mon.store.pending_count()
        boots = self.st.get("boots", [])
        lines = [f"Offline from {fmt_ts(since)} to {fmt_ts(t)} ({fmt_dur(t - since)})",
                 f"Cause at start: {self.st.get('cause') or '?'}"]
        if boots:
            lines.append("Machine rebooted during the outage: yes, booted at " + ", ".join(fmt_ts(x) for x in boots))
        else:
            lines.append("Machine rebooted during the outage: no")
        power = self.mon.store.events(kinds=("ac_lost", "ac_restored"), since=since - 120, until=t)
        for ts, _, kind, d in power[:6]:
            lines.append(f"• {fmt_short(ts)} {'AC lost' if kind == 'ac_lost' else 'AC restored'} (battery {d.get('bat', '?')}%)")
        mode = " (as a digest)" if spooled > self.cfg["digestThreshold"] else ""
        lines.append(f"Queued: {spooled} message(s), delivering now{mode}")
        self.mon.store.event("net_up", {"since": since, "duration": t - since}, t)
        self.st.update(state="online", since=t, cause=None, boots=[])
        LOG.info("network back online after %s", fmt_dur(t - since))
        self.mon.alert("Back online", "\n".join(lines), "ok", priority=2)


# ---------------------------------------------------------------- power

class Power:
    def __init__(self, mon):
        self.mon, self.cfg = mon, mon.cfg["power"]
        self.ac_name = self.cfg.get("ac") or self.find("Mains")
        self.bat_name = self.cfg.get("battery") or self.find("Battery")
        self.st = mon.store.kv_get("power")
        self.next = 0

    @staticmethod
    def find(kind):
        base = sysfs("/class/power_supply")
        try:
            for n in sorted(os.listdir(base)):
                if read_file(f"{base}/{n}/type") == kind:
                    return n
        except OSError:
            pass
        return None

    def read(self):
        base = sysfs("/class/power_supply")
        ac = read_file(f"{base}/{self.ac_name}/online") if self.ac_name else None
        cap = read_file(f"{base}/{self.bat_name}/capacity") if self.bat_name else None
        return {"ac": int(ac) if ac and ac.isdigit() else None,
                "bat": int(cap) if cap and cap.isdigit() else None,
                "status": read_file(f"{base}/{self.bat_name}/status") if self.bat_name else None}

    def due(self):
        return self.cfg["enable"] and now() >= self.next

    def poll(self):
        self.next = now() + self.mon.cfg["intervals"]["power"]
        cur = self.read()
        self.mon.cur_power = cur
        t = now()
        st = self.st
        if cur["ac"] is None:
            return
        if st is None:
            st = self.st = {"ac": cur["ac"], "since": t, "bat_at_change": cur["bat"], "alerted": []}
            if cur["ac"] == 0:
                self.mon.store.event("ac_lost", {"bat": cur["bat"], "at_start": True}, t)
                self.mon.alert("Running on battery", f"Monitor started while on battery ({cur['bat']}%).", "warn",
                               key="power:ac", cooldown=self.cfg["cooldown"])
        elif cur["ac"] != st["ac"]:
            dur = t - st["since"]
            if cur["ac"] == 0:
                self.mon.store.event("ac_lost", {"bat": cur["bat"]}, t)
                self.mon.alert("AC power LOST", f"Running on battery: {cur['bat']}% ({cur['status']}).\n"
                               f"AC had been on for {fmt_dur(dur)}.", "crit",
                               key="power:ac_lost", cooldown=self.cfg["cooldown"])
            else:
                self.mon.store.event("ac_restored", {"bat": cur["bat"], "on_battery": dur}, t)
                drop = (st.get("bat_at_change") or 0) - (cur["bat"] or 0)
                self.mon.alert("AC power restored", f"Was on battery for {fmt_dur(dur)} (since {fmt_ts(st['since'])}).\n"
                               f"Battery {st.get('bat_at_change')}% → {cur['bat']}% (-{max(drop, 0)} pts).", "ok",
                               key="power:ac_restored", cooldown=self.cfg["cooldown"])
            st.update(ac=cur["ac"], since=t, bat_at_change=cur["bat"], alerted=[])
        elif cur["ac"] == 0 and cur["bat"] is not None:
            crossed = [lvl for lvl in self.cfg["lowBattery"] if cur["bat"] <= lvl and lvl not in st["alerted"]]
            if crossed:  # one alert even if several thresholds were crossed at once
                lvl = min(crossed)
                st["alerted"] += crossed
                used = (st.get("bat_at_change") or cur["bat"]) - cur["bat"]
                el = t - st["since"]
                est = f", ~{fmt_dur(cur['bat'] / used * el)} left at this rate" if used > 0 and el > 60 else ""
                self.mon.store.event("bat_low", {"bat": cur["bat"], "level": lvl}, t)
                self.mon.alert(f"Battery low: {cur['bat']}%",
                               f"On battery since {fmt_ts(st['since'])} ({fmt_dur(el)}){est}.",
                               "crit" if lvl <= 10 else "warn", key=f"power:bat{lvl}", cooldown=0)
        st["bat"] = cur["bat"]
        self.mon.store.kv_set("power", st)


# ---------------------------------------------------------------- health checks

class Health:
    def __init__(self, mon):
        self.mon = mon
        self.next = now() + mon.cfg["intervals"]["healthDelay"]  # let automounts settle after boot

    def due(self):
        return now() >= self.next

    def run_local(self):
        self.next = now() + self.mon.cfg["intervals"]["health"]
        self.mon.refresh_usbmap()
        results = []
        for m in self.mon.cfg["mounts"]:
            try:
                results.append(self.check_mount(m))
            except Exception as e:
                LOG.exception("mount check failed")
                results.append({"id": f"mount:{m['path']}", "ok": False, "severity": "warn",
                                "title": f"{m['path']}: check crashed", "detail": str(e)})
        for s in self.mon.cfg["diskSpace"]:
            r = self.check_space(s)
            if r:
                results.append(r)
        self.apply("local", results)

    def uuid_missing(self, path):
        for m in self.mon.cfg["mounts"]:
            if m["path"] == path and m.get("uuid") and not os.path.exists(f"/dev/disk/by-uuid/{m['uuid']}"):
                return True
        return False

    def check_mount(self, m):
        path, uuid = m["path"], m.get("uuid")
        cid = f"mount:{path}"
        link = f"/dev/disk/by-uuid/{uuid}" if uuid else None
        if uuid and not os.path.exists(link):
            # don't touch the mount point: that would trigger the automount and a device wait loop
            if not m.get("required", True):
                return {"id": cid, "ok": True, "title": f"{path}: disk absent (not required)"}
            return {"id": cid, "ok": False, "severity": m.get("severity", "crit"),
                    "reminder": m.get("reminderInterval") or self.mon.cfg["reminderInterval"],
                    "title": f"{path}: disk MISSING",
                    "detail": f"UUID {uuid} not present (disk unplugged / not powered / dead)."}
        rc, _, err = run(["ls", "-1fq", "--", path], timeout=m.get("timeout", 15))  # also triggers the automount
        mi = read_mountinfo()
        ent = mount_for(path, mi)
        problems = []
        if not ent:
            problems.append("not mounted")
        else:
            if uuid:
                try:
                    st = os.stat(link)
                    want = f"{os.major(st.st_rdev)}:{os.minor(st.st_rdev)}"
                    real = os.path.basename(os.path.realpath(link))
                except OSError:
                    want, real = None, "?"
                if want and ent["majmin"] != want:
                    problems.append(f"STALE mount: mounted from {ent['source']} ({ent['majmin']}) but the disk is now "
                                    f"/dev/{real} ({want}); the mounted device is gone")
                elif not os.path.exists(sysfs(f"/dev/block/{ent['majmin']}")):
                    problems.append(f"STALE mount: source device {ent['source']} ({ent['majmin']}) no longer exists")
            if "shutdown" in ent["super"] or "shutdown" in ent["opts"]:
                problems.append("filesystem is SHUT DOWN (journal aborted)")
            if (ent["super"][:1] == ["ro"] or ent["opts"][:1] == ["ro"]) and not m.get("readOnly", False):
                problems.append("filesystem is READ-ONLY (errors=remount-ro?)")
        if rc is None:
            problems.append(f"listing timed out after {m.get('timeout', 15)}s (hung I/O?)")
        elif rc != 0:
            problems.append("listing failed: " + (err.strip().splitlines() or ["?"])[-1][:200])
        src = f"{ent['source']} [{ent['fstype']}]" if ent else "-"
        if problems:
            return {"id": cid, "ok": False, "severity": "crit", "title": f"{path}: " + problems[0].split(":")[0],
                    "detail": "\n".join(problems) + f"\nmounted: {src}"}
        return {"id": cid, "ok": True, "title": f"{path}: OK ({src})"}

    def check_space(self, s):
        path = s["path"]
        if self.uuid_missing(path):
            return None
        rc, out, err = run(["stat", "-f", "-c", "%b %a %S", "--", path], timeout=15)
        cid = f"space:{path}"
        if rc != 0:
            return None  # the mount check reports inaccessible mounts
        try:
            blocks, avail, bs = (int(x) for x in out.split())
        except ValueError:
            return None
        total, free = blocks * bs, avail * bs
        pct = 100.0 * free / total if total else 100.0
        gib = free / 2**30
        desc = f"{gib:.1f} GiB free ({pct:.1f}%) of {total / 2**30:.0f} GiB"
        sev = None
        if pct < s.get("critFreePercent", 5) or (s.get("critFreeGiB") and gib < s["critFreeGiB"]):
            sev = "crit"
        elif pct < s.get("warnFreePercent", 10) or (s.get("minFreeGiB") and gib < s["minFreeGiB"]):
            sev = "warn"
        if sev:
            return {"id": cid, "ok": False, "severity": sev, "title": f"{path}: low disk space", "detail": desc}
        return {"id": cid, "ok": True, "title": f"{path}: {desc}"}

    def apply(self, scope, results):
        """State machine: alert on change, remind while bad, report resolution."""
        t = now()
        mon = self.mon
        state = mon.store.kv_get("health", {})
        problems, reminders, resolved = [], [], []
        seen = set()
        for r in results:
            cid = r["id"]
            seen.add(cid)
            prev = state.get(cid)
            if not r["ok"]:
                sev = r.get("severity", "warn")
                if prev is None or prev["ok"]:
                    state[cid] = {"ok": False, "since": t, "last_alert": t, "scope": scope, "severity": sev,
                                  "title": r["title"]}
                    problems.append(r)
                else:
                    escalated = SEV_RANK[sev] > SEV_RANK.get(prev.get("severity", "warn"), 2)
                    prev.update(severity=sev, title=r["title"])
                    if escalated:
                        prev["last_alert"] = t
                        problems.append(r)
                    elif t - prev["last_alert"] >= r.get("reminder", mon.cfg["reminderInterval"]):
                        prev["last_alert"] = t
                        reminders.append((r, prev["since"]))
            else:
                if prev is not None and not prev["ok"]:
                    resolved.append((r, prev["since"]))
                if prev is None or not prev["ok"]:
                    state[cid] = {"ok": True, "since": t, "scope": scope, "title": r["title"]}
                else:
                    prev["title"] = r["title"]
        for cid in list(state):
            st = state[cid]
            if st.get("scope") == scope and cid not in seen:
                if not st["ok"]:
                    resolved.append(({"id": cid, "title": st["title"] + " (no longer checked)"}, st["since"]))
                del state[cid]
        mon.store.kv_set("health", state)
        if not (problems or reminders or resolved):
            return
        lines, sev = [], "ok"
        for r in problems:
            sev = max(sev, r.get("severity", "warn"), key=lambda s: SEV_RANK[s])
            lines.append(f"{SEV_ICON[r.get('severity', 'warn')]} {r['title']}")
            if r.get("detail"):
                lines += ["   " + x for x in r["detail"].splitlines()]
        for r, since in reminders:
            sev = max(sev, r.get("severity", "warn"), key=lambda s: SEV_RANK[s])
            lines.append(f"⏳ still failing since {fmt_ts(since)} ({fmt_dur(t - since)}): {r['title']}")
            if r.get("detail"):
                lines += ["   " + x for x in r["detail"].splitlines()[:3]]
        for r, since in resolved:
            lines.append(f"{SEV_ICON['ok']} resolved after {fmt_dur(t - since)}: {r['title']}")
        if problems:
            title = f"{len(problems)} problem(s)" + (f", {len(resolved)} resolved" if resolved else "")
        elif reminders:
            title = f"{len(reminders)} problem(s) still open"
        else:
            title = f"{len(resolved)} problem(s) resolved"
        mon.alert(f"Health ({scope}): {title}", "\n".join(lines), sev)


# ---------------------------------------------------------------- daemon

class Monitor:
    def __init__(self, cfg):
        self.cfg = cfg
        self.sd = cfg["stateDir"]
        os.makedirs(self.sd, exist_ok=True)
        inc = incoming_dir(cfg)
        os.makedirs(inc, exist_ok=True)
        try:
            os.chmod(inc, 0o1730 if os.stat(inc).st_uid == os.getuid() else os.stat(inc).st_mode & 0o7777)
        except OSError:
            pass
        self.boot_id = get_boot_id()
        self.btime = get_btime()
        self.store = Store(os.path.join(self.sd, "state.db"), self.boot_id)
        self.store_cursor = self.store.kv_get("journal_cursor")
        self.stop_evt = threading.Event()
        self.tg = Telegram(cfg)
        self.usbmap = self.store.kv_get("usbmap", {})
        self.cur_power = {"ac": None, "bat": None, "status": None}
        self.net = Network(self)
        self.power = Power(self)
        self.health = Health(self)
        self.journal = JournalWatcher(self)
        self.next_hb = 0
        self.block_until = 0
        self.noconf_logged = False
        self.send_delay = float(os.environ.get("SERVERMON_SEND_DELAY", "1"))

    # -- alerts / rate limiting
    def alert(self, title, body="", severity="warn", key=None, cooldown=None, pre=None, priority=0, created=None):
        t = now()
        created = created or t
        if key:
            cd = self.cfg["cooldown"] if cooldown is None else cooldown
            r = self.store.db.execute("SELECT * FROM ratelimit WHERE key=?", (key,)).fetchone()
            if r and cd > 0 and t - r["last_sent"] < cd:
                self.store.db.execute(
                    "UPDATE ratelimit SET suppressed=suppressed+1, first_suppressed=COALESCE(first_suppressed, ?),"
                    " last_title=?, severity=?, cooldown=? WHERE key=?", (created, title, severity, cd, key))
                LOG.info("suppressed [%s] %s", key, title)
                return
            if r and r["suppressed"]:
                body = (body + "\n" if body else "") + \
                    f"(+{r['suppressed']} similar suppressed since {fmt_ts(r['first_suppressed'])})"
            self.store.db.execute("INSERT OR REPLACE INTO ratelimit(key,last_sent,cooldown,suppressed,first_suppressed,"
                                  "last_title,severity) VALUES(?,?,?,0,NULL,?,?)", (key, t, cd, title, severity))
        self.store.enqueue(created, key, severity, title, body, pre, priority)
        LOG.info("queued [%s] %s", severity, title)

    def ratelimit_sweep(self):
        """After the cooldown, summarize what was suppressed (an ongoing problem gets a reminder)."""
        t = now()
        rows = self.store.db.execute("SELECT * FROM ratelimit WHERE suppressed>0 AND ?-last_sent>=cooldown", (t,)).fetchall()
        for r in rows:
            self.store.enqueue(t, r["key"], r["severity"] or "warn", f"Repeated: {r['last_title']}",
                               f"{r['suppressed']} similar alert(s) suppressed in the last {fmt_dur(t - r['last_sent'])} "
                               f"(first at {fmt_ts(r['first_suppressed'])}).", "", 0)
            self.store.db.execute("UPDATE ratelimit SET last_sent=?, suppressed=0, first_suppressed=NULL WHERE key=?",
                                  (t, r["key"]))
        self.store.db.execute("DELETE FROM ratelimit WHERE suppressed=0 AND ?-last_sent > MAX(cooldown, 86400)", (t,))
        # hard cap so a long misconfiguration can't grow the spool forever
        self.store.db.execute("DELETE FROM outbox WHERE priority<=0 AND id NOT IN "
                              "(SELECT id FROM outbox ORDER BY id DESC LIMIT 5000)")

    # -- misc state
    def save_cursor(self, c):
        self.store_cursor = {"boot": self.boot_id, "cursor": c}
        self.store.kv_set("journal_cursor", self.store_cursor)

    def refresh_usbmap(self):
        cur = usb_storage_map()
        if cur:
            self.usbmap.update(cur)
            self.store.kv_set("usbmap", self.usbmap)

    def path_for_device(self, dev):
        for m in self.cfg["mounts"]:
            if m.get("uuid") and m["uuid"] in dev:
                return m["path"]
        return None

    def heartbeat(self, final=False):
        on_bat = self.cur_power.get("ac") == 0
        iv = self.cfg["intervals"]["heartbeatOnBattery" if on_bat else "heartbeat"]
        self.next_hb = now() + iv
        hb = {"ts": now(), "boot_id": self.boot_id, "btime": self.btime, "ac": self.cur_power.get("ac"),
              "bat": self.cur_power.get("bat"), "bat_status": self.cur_power.get("status"),
              "net": self.net.state, "pid": os.getpid(), "final": final}
        try:
            atomic_write_json(os.path.join(self.sd, "heartbeat.json"), hb)
        except OSError as e:
            LOG.error("heartbeat write failed: %s", e)

    # -- incoming spool
    def ingest(self):
        d = incoming_dir(self.cfg)
        try:
            names = sorted(n for n in os.listdir(d) if not n.startswith("."))
        except OSError:
            return
        for n in names:
            p = os.path.join(d, n)
            obj = read_json(p)
            if obj is None:
                LOG.warning("dropping unreadable spool file %s", n)
            elif obj.get("type") == "checks":
                self.health.apply(obj.get("scope", "ext"), obj.get("results", []))
            else:
                sev = obj.get("severity", "info")
                self.alert(str(obj.get("title") or "Notification"), str(obj.get("body") or ""),
                           sev if sev in SEV_RANK else "info", key=obj.get("key"), cooldown=obj.get("cooldown"),
                           pre=obj.get("pre"), created=obj.get("created"))
            try:
                os.unlink(p)
            except OSError as e:
                LOG.error("cannot remove %s: %s", p, e)

    # -- delivery
    def deliver(self, budget=20):
        t = now()
        if t < self.block_until:
            return
        if self.net.state == "offline" and not self.net.due():
            return
        rows = self.store.pending(t)
        if not rows:
            return
        tok, chat = self.tg.credentials()
        if not tok or not chat:
            if not self.noconf_logged:
                LOG.warning("telegram token/chat_id not configured: %d message(s) stay spooled", len(rows))
                self.noconf_logged = True
            return
        prio = [r for r in rows if r["priority"] > 0]
        rest = [r for r in rows if r["priority"] <= 0]
        batches = [([r], render(self.cfg, r, t)) for r in prio]
        if len(rest) > self.cfg["network"]["digestThreshold"]:
            batches += self.digest(rest, t)
        else:
            batches += [([r], render(self.cfg, r, t)) for r in rest]
        for i, (rs, text) in enumerate(batches[:budget]):
            if i:
                time.sleep(self.send_delay)
            status, delay = self.tg.send(text)
            if status == "bad":  # HTML rejected: retry as plain text once
                status, delay = self.tg.send(strip_html(text), html_mode=False)
                if status == "bad":
                    LOG.error("dropping undeliverable message: %s", rs[0]["title"])
                    status = "ok"
            if status == "ok":
                self.store.mark_sent([r["id"] for r in rs])
                if self.net.state != "online":
                    self.net.success()
                continue
            if status == "net":
                self.net.failure("telegram send failed")
                self.block_until = now() + 30
            elif status in ("retry", "auth"):
                # pause the whole queue (keeps the order), e.g. 429 retry_after or a bad token
                for r in rs:
                    self.store.defer(r["id"], 0, status)
                self.block_until = now() + (delay or 60)
            break

    def digest(self, rows, t):
        items = []
        for r in rows:
            first = [x.strip() for x in (r["body"] or "").strip().splitlines()[:2]]
            s = f"{SEV_ICON.get(r['severity'], '')} <b>{fmt_short(r['created'])}</b> {esc(r['title'])}"
            if first:
                s += "\n   " + esc(cut(" / ".join(first), 240))
            items.append((r, s))
        chunks, cur, size = [], [], 0
        for r, s in items:
            if cur and size + len(s) > 3500:
                chunks.append(cur)
                cur, size = [], 0
            cur.append((r, s))
            size += len(s) + 1
        if cur:
            chunks.append(cur)
        out = []
        for i, ch in enumerate(chunks, 1):
            head = (f"\U0001f4e6 <b>{esc(self.cfg['hostname'])}</b> · <b>Backlog {i}/{len(chunks)}</b> "
                    f"({len(rows)} queued messages, oldest {fmt_ts(rows[0]['created'])})")
            out.append(([r for r, _ in ch], head + "\n" + "\n".join(s for _, s in ch)))
        return out

    # -- boot / shutdown
    def boot_report(self):
        hb = read_json(os.path.join(self.sd, "heartbeat.json"))
        stopped = read_json(os.path.join(self.sd, "stopped.json")) or {}
        marker = read_json(os.path.join(self.sd, "shutdown.json")) or {}
        t = now()
        if not hb:
            self.alert("servermon started", f"First start (no previous state). Booted {fmt_ts(self.btime)}.", "info",
                       priority=1)
            return
        if hb.get("boot_id") == self.boot_id:
            gap = t - hb["ts"]
            if gap > 600 and not hb.get("final"):
                self.alert("servermon restarted", f"Monitor was not running for {fmt_dur(gap)} "
                           f"(last heartbeat {fmt_ts(hb['ts'])}).", "warn", priority=1)
            return
        prev = hb["boot_id"]
        net = self.net.st
        if net.get("state") == "offline":
            net.setdefault("boots", []).append(self.btime)
            self.net.save()
        clean = (marker.get("boot_id") == prev) or (stopped.get("boot_id") == prev and stopped.get("system_stopping"))
        kind = marker.get("kind") or stopped.get("kind") or "shutdown"
        last_seen = hb["ts"]
        jlast = self.last_journal_ts(prev)
        if jlast and jlast > last_seen:
            last_seen = jlast
        lines = [f"Booted at {fmt_ts(self.btime)}."]
        if hb.get("btime"):
            lines.append(f"Previous boot: {fmt_ts(hb['btime'])}, uptime {fmt_dur(last_seen - hb['btime'])}.")
        if stopped.get("boot_id") == prev and not stopped.get("system_stopping"):
            lines.append(f"(servermon itself had been stopped at {fmt_ts(stopped['ts'])}, outside a shutdown)")
        if clean:
            st = marker.get("ts") or stopped.get("ts")
            lines.append(f"Clean {kind} at {fmt_ts(st)}; down for {fmt_dur(self.btime - st)}.")
            sev = "info"
        else:
            lines.append(f"UNCLEAN shutdown (no shutdown marker). Last heartbeat {fmt_ts(hb['ts'])}: "
                         f"AC {'on' if hb.get('ac') else 'OFF' if hb.get('ac') == 0 else '?'}, "
                         f"battery {hb.get('bat', '?')}%, network {hb.get('net', '?')}.")
            if jlast:
                lines.append(f"Last journal entry of that boot: {fmt_ts(jlast)}.")
            if hb.get("ac") == 0:
                why = "battery ran out" if (hb.get("bat") or 100) <= 15 else "power died while on battery"
            else:
                why = "crash / hang / forced power-off while on AC"
            lines.append(f"Likely cause: {why}. Machine was dead ~{fmt_dur(self.btime - last_seen)}.")
            sev = "crit"
        ev = self.store.events(boot_id=prev, kinds=("ac_lost", "ac_restored", "bat_low", "net_down", "net_up"))
        if ev:
            names = {"ac_lost": "AC lost (battery {bat}%)", "ac_restored": "AC restored (battery {bat}%)",
                     "bat_low": "battery {bat}%", "net_down": "network lost ({cause})", "net_up": "network back"}
            tl = [(ts, names[k].format(bat=d.get("bat"), cause=d.get("cause"))) for ts, _, k, d in ev[-12:]]
            tl.append((hb["ts"], f"last heartbeat (AC {'on' if hb.get('ac') else 'off'}, battery {hb.get('bat', '?')}%)"))
            if jlast and jlast > hb["ts"]:
                tl.append((jlast, "last journal entry"))
            tl.append((self.btime, "booted"))
            lines.append("Timeline:")
            lines += [f"• {fmt_ts(ts)} {txt}" for ts, txt in sorted(tl)]
        if net.get("state") == "offline":
            lines.append(f"Network offline since {fmt_ts(net['since'])} (as of the last check).")
        self.store.event("boot", {"prev": prev, "clean": clean}, self.btime)
        self.alert("Boot report" + ("" if clean else ": UNCLEAN shutdown"), "\n".join(lines), sev, priority=3,
                   created=t)

    def last_journal_ts(self, boot):
        b = boot.replace("-", "")
        rc, out, _ = run(["journalctl", f"--boot={b}", "-n", "1", "-o", "json", "--no-pager"], timeout=20)
        if rc == 0 and out.strip():
            try:
                return int(json.loads(out.strip().splitlines()[-1])["__REALTIME_TIMESTAMP"]) / 1e6
            except (ValueError, KeyError):
                pass
        return None

    def on_stop(self):
        stopping, kind = system_stopping()
        up = now() - self.btime
        try:
            atomic_write_json(os.path.join(self.sd, "stopped.json"),
                              {"ts": now(), "boot_id": self.boot_id, "system_stopping": stopping, "kind": kind,
                               "uptime": up})
        except OSError as e:
            LOG.error("cannot write stop marker: %s", e)
        self.heartbeat(final=True)
        if stopping:
            self.alert(f"Going down ({kind})", f"Uptime {fmt_dur(up)}. Spooled: {self.store.pending_count()}.",
                       "info", priority=1)
            end = now() + 5
            while now() < end and self.store.pending(now() + 1e9):
                if self.net.state == "offline":
                    break
                n = self.store.pending_count()
                self.deliver(budget=3)
                if self.store.pending_count() == n:
                    break

    def run(self, run_for=None):
        LOG.info("servermon starting (boot %s)", self.boot_id)
        signal.signal(signal.SIGTERM, lambda *_: self.stop_evt.set())
        signal.signal(signal.SIGINT, lambda *_: self.stop_evt.set())
        if self.cfg["power"]["enable"]:
            self.power.poll()
        self.boot_report()
        for f in ("stopped.json", "shutdown.json"):  # consumed by the boot report
            try:
                os.unlink(os.path.join(self.sd, f))
            except OSError:
                pass
        self.refresh_usbmap()
        self.heartbeat()
        if self.cfg["journal"]["enable"]:
            self.journal.start()
        end = now() + run_for if run_for else None
        tick = self.cfg["intervals"]["tick"]
        while not self.stop_evt.is_set():
            try:
                self.ingest()
                if self.cfg["journal"]["enable"]:
                    self.journal.process()
                    self.journal.flush()
                if self.power.due():
                    self.power.poll()
                if self.net.due():
                    self.net.probe()
                if self.health.due():
                    self.health.run_local()
                if now() >= self.next_hb:
                    self.heartbeat()
                self.ratelimit_sweep()
                self.deliver()
            except sqlite3.Error:
                LOG.exception("database error")
            except Exception:
                LOG.exception("main loop error")
            if end and now() >= end:
                break
            self.stop_evt.wait(tick)
        self.journal.stop()
        self.journal.flush(force=True)
        self.on_stop()
        LOG.info("servermon stopped")


# ---------------------------------------------------------------- other subcommands

def cmd_notify(cfg, a):
    body = " ".join(a.message) if a.message else ("" if sys.stdin.isatty() else sys.stdin.read())
    pre = a.pre
    if a.pre_file:
        pre = read_file(a.pre_file, "")
    title = a.title or (body.strip().splitlines() or ["Notification"])[0][:120]
    if not a.title:
        body = "\n".join(body.strip().splitlines()[1:])
    drop_incoming(cfg, {"type": "message", "title": title, "body": body, "severity": a.severity, "key": a.key,
                        "cooldown": a.cooldown, "pre": pre})


def cmd_failure(cfg, a):
    unit = a.unit
    props = {}
    rc, out, _ = run(["systemctl", "show", unit, "--no-pager", "-p", "Result", "-p", "ExecMainStatus", "-p",
                      "ExecMainCode", "-p", "NRestarts", "-p", "Description", "-p", "ActiveEnterTimestamp"], timeout=10)
    for line in out.splitlines():
        k, _, v = line.partition("=")
        props[k] = v
    rc, logs, err = run(["journalctl", "-u", unit, "-n", str(a.lines), "-o", "short-iso", "--no-pager", "-q"],
                        timeout=20)
    body = f"{props.get('Description', '')}\nResult: {props.get('Result', '?')}, exit status {props.get('ExecMainStatus', '?')}"
    if props.get("NRestarts", "0") not in ("", "0"):
        body += f", restarts: {props['NRestarts']}"
    drop_incoming(cfg, {"type": "message", "title": f"Service failed: {unit}", "body": body, "severity": "crit",
                        "key": f"failure:{unit}", "cooldown": a.cooldown, "pre": logs.strip() or err.strip()})


def read_api_key(inst):
    cred = os.environ.get("CREDENTIALS_DIRECTORY")
    p = os.path.join(cred, inst["name"]) if cred and os.path.exists(os.path.join(cred, inst["name"])) else inst.get("apiKeyFile")
    raw = read_file(p) if p else None
    if not raw:
        return None, ""
    if "<ApiKey>" in raw:  # an *arr config.xml
        root = ET.fromstring(raw)
        base = (root.findtext("UrlBase") or "").strip().strip("/")
        return (root.findtext("ApiKey") or "").strip(), ("/" + base if base else "")
    return raw.strip(), ""


STUCK_STATES = ("importPending", "importBlocked", "failedPending")


def cmd_arr_check(cfg, a):
    acfg = cfg["arr"]
    spath = os.path.join(cfg["stateDir"], "arr-state.json")
    state = read_json(spath) or {}
    t = now()
    results = []
    for inst in acfg["instances"]:
        name = inst["name"]
        try:
            key, base = read_api_key(inst)
        except (OSError, ET.ParseError) as e:
            key, base = None, str(e)
        if not key:
            results.append({"id": f"arr:{name}:api", "ok": False, "severity": "warn",
                            "title": f"{name}: cannot read API key", "detail": base or inst.get("apiKeyFile", "")})
            continue
        url = (inst["url"].rstrip("/") + base + "/api/v3/queue?page=1&pageSize=500"
               "&includeUnknownSeriesItems=true&includeUnknownMovieItems=true")
        try:
            req = urllib.request.Request(url, headers={"X-Api-Key": key, "Accept": "application/json"})
            with urllib.request.urlopen(req, timeout=30) as r:
                data = json.loads(r.read().decode())
        except (urllib.error.URLError, OSError, ValueError) as e:
            results.append({"id": f"arr:{name}:api", "ok": False, "severity": "warn",
                            "title": f"{name}: API unreachable", "detail": str(e)[:300]})
            continue
        results.append({"id": f"arr:{name}:api", "ok": True, "title": f"{name}: API OK"})
        groups = {}
        for r in data.get("records", []):
            st, stat = r.get("trackedDownloadState"), r.get("trackedDownloadStatus")
            if not (st in STUCK_STATES or (r.get("status") == "completed" and stat in ("warning", "error"))):
                continue
            k = f"{name}:{r.get('downloadId') or r.get('id')}:{st}"
            g = groups.setdefault(k, {"title": r.get("title", "?"), "state": st, "n": 0, "msgs": []})
            g["n"] += 1
            for sm in r.get("statusMessages") or []:
                for msg in sm.get("messages") or []:
                    if msg not in g["msgs"]:
                        g["msgs"].append(msg)
        stuck = []
        for k, g in groups.items():
            first = state.setdefault(k, t)
            if t - first >= acfg["stuckAfter"]:
                stuck.append((first, g))
        for k in [k for k in state if k.startswith(name + ":") and k not in groups]:
            del state[k]
        if stuck:
            stuck.sort(key=lambda x: x[0])
            det = []
            for first, g in stuck[:10]:
                det.append(f"• {g['title']} [{g['state']}" + (f", {g['n']} items" if g["n"] > 1 else "")
                           + f"] for {fmt_dur(t - first)}" + (f": {g['msgs'][0][:150]}" if g["msgs"] else ""))
            if len(stuck) > 10:
                det.append(f"… and {len(stuck) - 10} more")
            results.append({"id": f"arr:{name}:stuck", "ok": False, "severity": "warn",
                            "title": f"{name}: {len(stuck)} download(s) stuck waiting to import", "detail": "\n".join(det)})
        else:
            results.append({"id": f"arr:{name}:stuck", "ok": True, "title": f"{name}: no stuck imports"})
    atomic_write_json(spath, state)
    drop_incoming(cfg, {"type": "checks", "scope": "arr", "results": results})
    if a.verbose:
        print(json.dumps(results, indent=1))


def cmd_mark_shutdown(cfg, a):
    stopping, kind = system_stopping()
    if not stopping and not a.force:
        LOG.info("system is not shutting down; no marker written")
        return
    atomic_write_json(os.path.join(cfg["stateDir"], "shutdown.json"),
                      {"ts": now(), "boot_id": get_boot_id(), "kind": kind or "shutdown"})


def cmd_status(cfg, a):
    sd = cfg["stateDir"]
    print("heartbeat:", json.dumps(read_json(os.path.join(sd, "heartbeat.json"))))
    db = sqlite3.connect(f"file:{os.path.join(sd, 'state.db')}?mode=ro", uri=True)
    for k, v in db.execute("SELECT k, v FROM kv WHERE k IN ('net','power','health')"):
        print(f"{k}: {v}")
    print("outbox:", db.execute("SELECT COUNT(*) FROM outbox").fetchone()[0])
    for r in db.execute("SELECT created, severity, title, attempts, last_error FROM outbox ORDER BY id LIMIT 20"):
        print(f"  {fmt_ts(r[0])} [{r[1]}] {r[2]} (attempts {r[3]}, {r[4]})")
    print("last sent:")
    for r in db.execute("SELECT sent, title FROM sent ORDER BY id DESC LIMIT 10"):
        print(f"  {fmt_ts(r[0])} {r[1]}")


def main(argv=None):
    ap = argparse.ArgumentParser(prog="servermon")
    ap.add_argument("--config", help="JSON config (default: $SERVERMON_CONFIG)")
    ap.add_argument("-v", "--verbose", action="store_true")
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("daemon")
    p.add_argument("--run-for", type=float, help="exit after N seconds (testing)")
    p = sub.add_parser("notify", help="enqueue a message")
    p.add_argument("-t", "--title")
    p.add_argument("-s", "--severity", default="info", choices=list(SEV_RANK))
    p.add_argument("-k", "--key", help="dedup/rate-limit key")
    p.add_argument("-c", "--cooldown", type=int, help="seconds between two messages with the same key")
    p.add_argument("--pre", help="preformatted text (logs)")
    p.add_argument("--pre-file")
    p.add_argument("message", nargs="*")
    p = sub.add_parser("failure")
    p.add_argument("unit")
    p.add_argument("-n", "--lines", type=int, default=15)
    p.add_argument("-c", "--cooldown", type=int, default=1800)
    sub.add_parser("arr-check")
    p = sub.add_parser("mark-shutdown")
    p.add_argument("--force", action="store_true")
    sub.add_parser("status")
    a = ap.parse_args(argv)
    logging.basicConfig(level=logging.DEBUG if a.verbose else logging.INFO, stream=sys.stderr,
                        format="%(levelname)s %(message)s")
    cfg = load_config(a.config)
    if a.cmd == "daemon":
        Monitor(cfg).run(a.run_for)
    else:
        {"notify": cmd_notify, "failure": cmd_failure, "arr-check": cmd_arr_check,
         "mark-shutdown": cmd_mark_shutdown, "status": cmd_status}[a.cmd](cfg, a)


if __name__ == "__main__":
    main()
