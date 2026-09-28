"""Render vault Git history as static diff pages and serve them with Basic Auth."""

import argparse
import base64
import binascii
import codecs
import difflib
import html
import hmac
import json
import os
import re
import subprocess
import tempfile
from datetime import datetime
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


# Pages are cached per commit; bump to re-render them after changing the layout.
VERSION = 2
PAGE_SIZE = 100
MAX_DIFF_LINES = 20000
MAX_PAIR_CHARS = 3000  # word diffs are quadratic; longer lines (minified plugins, JSON) stay plain
HERMES_REF = "refs/heads/hermes"
SNAPSHOT_SUBJECT = re.compile(r"snapshot \d{4}-\d\d-\d\dT\S+")
HUNK = re.compile(r"@@ -\d+(?:,(\d+))? \+(\d+)(?:,(\d+))? @@ ?(.*)")
TASK = re.compile(r"(\s*(?:[-*+]|\d+[.)])\s+\[)(.)(\]\s?)(.*)")
# Obsidian Tasks appends these when a task is completed or cancelled
TASK_STAMP = re.compile(r"\s*[✅❌]\s*\d{4}-\d\d-\d\d\s*$")
TASK_LABELS = {"x": "done", "X": "done", " ": "reopened", "-": "cancelled", "/": "in progress"}
TOKEN = re.compile(r"\w+|\s+|[^\w\s]")

STYLE = """
:root{color-scheme:dark;--bg:#15181c;--fg:#dde1e6;--muted:#8b949e;--card:#1d2228;--line:#2d333b;--link:#8dc8ff;
--add:rgba(46,160,67,.15);--add-hi:rgba(46,160,67,.45);--del:rgba(248,81,73,.13);--del-hi:rgba(248,81,73,.42);
--mod:rgba(210,153,34,.07);--addfg:#7ee787;--delfg:#ff9492;--task:rgba(56,139,253,.13);--hermes:#c3a6ff}
@media(prefers-color-scheme:light){:root{color-scheme:light;--bg:#fff;--fg:#1f2328;--muted:#656d76;--card:#f6f8fa;
--line:#d0d7de;--link:#0969da;--add:#e6ffec;--add-hi:#abf2bc;--del:#ffebe9;--del-hi:#ffb8b3;--mod:#fff8e5;
--addfg:#1a7f37;--delfg:#cf222e;--task:#ddf4ff;--hermes:#8250df}}
*{box-sizing:border-box}
body{font:15px/1.5 system-ui,sans-serif;max-width:1000px;margin:0 auto;padding:1rem;color:var(--fg);background:var(--bg)}
a{color:var(--link);text-decoration:none}a:hover{text-decoration:underline}
h1{font-size:1.35rem;margin:.4rem 0 .2rem;overflow-wrap:anywhere}
h2.day{font-size:.8rem;text-transform:uppercase;letter-spacing:.05em;color:var(--muted);margin:1.4rem 0 .4rem}
nav{margin:.2rem 0 .8rem}
.tabs a{display:inline-block;padding:.25rem .8rem;border-radius:999px;margin:0 .3rem .3rem 0;border:1px solid var(--line)}
.tabs a.on{background:var(--card);color:var(--fg);font-weight:600}
.meta{color:var(--muted);font-size:.9rem;margin:0 0 1rem}
.badge{display:inline-block;font-size:.7rem;font-weight:600;padding:0 .45rem;border-radius:999px;border:1px solid var(--line);
color:var(--muted);white-space:nowrap}
.badge.hermes{color:var(--hermes);border-color:var(--hermes)}
.badge.added{color:var(--addfg);border-color:var(--addfg)}.badge.deleted{color:var(--delfg);border-color:var(--delfg)}
ul.log{list-style:none;padding:0;margin:0}
ul.log li{border:1px solid var(--line);border-radius:.5rem;margin:.35rem 0;background:var(--card)}
ul.log a{display:flex;flex-wrap:wrap;gap:.2rem .6rem;align-items:baseline;padding:.5rem .75rem;color:var(--fg)}
ul.log a:hover{text-decoration:none;background:var(--line)}
.time{color:var(--muted);font-variant-numeric:tabular-nums}
.title{flex:1;min-width:10rem;overflow-wrap:anywhere}
.files{flex-basis:100%;color:var(--muted);font-size:.85rem;overflow-wrap:anywhere}
.stat{white-space:nowrap;font-size:.85rem;font-variant-numeric:tabular-nums}
.stat .a{color:var(--addfg)}.stat .r{color:var(--delfg)}.stat .t{color:var(--link)}
details.file{border:1px solid var(--line);border-radius:.5rem;margin:.8rem 0;overflow:hidden}
details.file>summary{padding:.45rem .75rem;background:var(--card);cursor:pointer;display:flex;flex-wrap:wrap;gap:.2rem .5rem;
align-items:baseline}
details.file[open]>summary{border-bottom:1px solid var(--line)}
.path{flex:1;overflow-wrap:anywhere}.dir{color:var(--muted)}
.diff{font:13px/1.55 ui-monospace,SFMono-Regular,Menlo,Consolas,monospace}
.l{display:grid;grid-template-columns:1.7em 1fr;min-height:1.55em}
.l .s{text-align:center;color:var(--muted);user-select:none}
.l .c{white-space:pre-wrap;overflow-wrap:anywhere;padding-right:.6rem;tab-size:4}
.add{background:var(--add)}.add .s{color:var(--addfg)}
.del{background:var(--del)}.del .s{color:var(--delfg)}
.mod{background:var(--mod)}.task{background:var(--task)}.task .s,.mark{color:var(--link)}
ins{background:var(--add-hi);text-decoration:none;border-radius:.2em}
del{background:var(--del-hi);border-radius:.2em}
.pill{font:600 .68rem system-ui,sans-serif;padding:.05rem .45rem;border-radius:999px;background:var(--link);color:var(--bg);
margin-left:.5rem;white-space:nowrap}
.hunk{color:var(--muted);background:var(--card);padding:.1rem .75rem;font:12px/1.6 system-ui,sans-serif;
border-bottom:1px solid var(--line)}
.l+.hunk{border-top:1px solid var(--line)}
.note{color:var(--muted);padding:.5rem .75rem;font-style:italic}
details.raw{margin-top:1.5rem}details.raw>summary{color:var(--muted);cursor:pointer}
pre{white-space:pre-wrap;overflow-wrap:anywhere;padding:.8rem;background:var(--card);border-radius:.5rem;
font:12px/1.5 ui-monospace,SFMono-Regular,Menlo,Consolas,monospace}
.pager{display:flex;justify-content:space-between;margin-top:1rem}
"""


def _git(git_bin, repo, work_tree, *args, env=None):
    result = subprocess.run(
        [git_bin, "-c", "core.quotePath=false", f"--git-dir={repo}", f"--work-tree={work_tree}", *args],
        check=True,
        capture_output=True,
        env=env,
    )
    return result.stdout.decode("utf-8", errors="replace")


def _page(title, body):
    return (
        "<!doctype html><html lang=\"en\"><meta charset=\"utf-8\">"
        "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">"
        f"<title>{html.escape(title)}</title><style>{STYLE}</style>"
        f"<body>{body}</body></html>"
    )


def _write_atomic(path, content):
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=path.parent, delete=False) as file:
        temp_path = Path(file.name)
        file.write(content)
    try:
        os.chmod(temp_path, 0o640)
        os.replace(temp_path, path)
    finally:
        temp_path.unlink(missing_ok=True)


def _strip_prefix(path):
    path = path.rstrip("\t")  # git appends a tab when the name contains a space
    if path.startswith('"') and path.endswith('"'):  # C-quoted: quotes, backslashes, control chars
        path = codecs.escape_decode(path[1:-1].encode("utf-8"))[0].decode("utf-8", errors="replace")
    return path[2:] if path[:2] in ("a/", "b/") else path


def _parse_patch(patch):
    """Split a unified diff into files with hunks; hunk sizes tell body lines from headers."""
    files, current, old_left, new_left, seen = [], None, 0, 0, 0
    truncated = False
    for line in patch.split("\n"):
        if old_left > 0 or new_left > 0:
            seen += 1
            if seen > MAX_DIFF_LINES:
                truncated = True
                break
            kind = line[:1]
            if kind == "\\":  # "\ No newline at end of file"
                continue
            if kind in ("-", " ", ""):
                old_left -= 1
            if kind in ("+", " ", ""):
                new_left -= 1
            current["hunks"][-1]["lines"].append((kind if kind in "+-" else " ", line[1:]))
            continue
        if line.startswith("diff --git "):
            current = {"header": line[11:], "old": None, "new": None, "status": "modified",
                       "binary": False, "hunks": []}
            files.append(current)
        elif current is None:
            continue
        elif match := HUNK.match(line):
            old_left = int(match[1] or 1)
            new_left = int(match[3] or 1)
            current["hunks"].append({"start": int(match[2]), "context": match[4], "lines": []})
        elif line.startswith("new file mode"):
            current["status"] = "added"
        elif line.startswith("deleted file mode"):
            current["status"] = "deleted"
        elif line.startswith("rename from "):
            current["status"], current["old"] = "renamed", line[12:]
        elif line.startswith("rename to "):
            current["new"] = line[10:]
        elif line.startswith("Binary files "):
            current["binary"] = True
        elif line.startswith("--- ") and line[4:] != "/dev/null":
            current["old"] = _strip_prefix(line[4:])
        elif line.startswith("+++ ") and line[4:] != "/dev/null":
            current["new"] = _strip_prefix(line[4:])
    for file in files:
        header = file["header"]
        half = (len(header) - 5) // 2  # "a/<path> b/<path>" when the path is unchanged
        same = header[:2] == "a/" and header[2 + half:5 + half] == " b/" and header[2:2 + half] == header[5 + half:]
        fallback = header[2:2 + half] if same else header
        file["path"] = file["new"] or file["old"] or fallback
    return files, truncated


def _task_toggle(old, new):
    """Checkbox marks when only a task's status (and its done/cancelled date) changed."""
    a, b = TASK.fullmatch(old), TASK.fullmatch(new)
    if not a or not b or a[2] == b[2] or a[1] != b[1]:
        return None
    if TASK_STAMP.sub("", a[4]) != TASK_STAMP.sub("", b[4]):
        return None
    return a[2], b[2]


def _similarity(old, new):
    return difflib.SequenceMatcher(None, TOKEN.findall(old), TOKEN.findall(new), autojunk=False).ratio()


def _pair(removed, added):
    """Match edited lines in order; unmatched ones stay plain removals and additions."""
    if len(removed) * len(added) > 400:
        return []
    pairs, start = [], 0
    for i, old in enumerate(removed):
        best, best_j = 0.5, None
        for j in range(start, len(added)):
            if _task_toggle(old, added[j]):
                score = 1.0
            elif len(old) + len(added[j]) > MAX_PAIR_CHARS:
                continue
            else:
                score = _similarity(old, added[j])
            if score > best:
                best, best_j = score, j
        if best_j is not None:
            pairs.append((i, best_j))
            start = best_j + 1
    return pairs


def _inline(old, new):
    a, b = TOKEN.findall(old), TOKEN.findall(new)
    out = []
    for op, i1, i2, j1, j2 in difflib.SequenceMatcher(None, a, b, autojunk=False).get_opcodes():
        if op == "equal":
            out.append(html.escape("".join(a[i1:i2])))
            continue
        if i2 > i1:
            out.append(f"<del>{html.escape(''.join(a[i1:i2]))}</del>")
        if j2 > j1:
            out.append(f"<ins>{html.escape(''.join(b[j1:j2]))}</ins>")
    return "".join(out)


def _row(kind, sign, content):
    return f'<div class="l {kind}"><span class="s">{sign}</span><span class="c">{content}</span></div>'


def _change_rows(removed, added, stats):
    rows, ri, ai = [], 0, 0

    def plain(kind, lines):
        stats["added" if kind == "add" else "removed"] += len(lines)
        return [_row(kind, "+" if kind == "add" else "−", html.escape(line)) for line in lines]

    for i, j in _pair(removed, added):
        rows += plain("del", removed[ri:i]) + plain("add", added[ai:j])
        old, new = removed[i], added[j]
        if marks := _task_toggle(old, new):
            match = TASK.fullmatch(new)
            label = TASK_LABELS.get(marks[1], "status changed")
            stats["tasks"] += 1
            stats["done"] += marks[1] in "xX"
            rows.append(_row("task", "✓" if marks[1] in "xX" else "•",
                             f'{html.escape(match[1])}<b class="mark">{html.escape(match[2])}</b>'
                             f'{html.escape(match[3] + match[4])}<span class="pill">{label}</span>'))
        else:
            stats["added"] += 1
            stats["removed"] += 1
            rows.append(_row("mod", "±", _inline(old, new)))
        ri, ai = i + 1, j + 1
    return rows + plain("del", removed[ri:]) + plain("add", added[ai:])


def _file_html(file, stats, open_):
    rows = []
    for hunk in file["hunks"]:
        if hunk["start"] > 1 or hunk["context"]:
            label = f"Line {hunk['start']}" + (f" · {hunk['context']}" if hunk["context"] else "")
            rows.append(f'<div class="hunk">{html.escape(label)}</div>')
        lines, k = hunk["lines"], 0
        while k < len(lines):
            if lines[k][0] == " ":
                rows.append(_row("ctx", "", html.escape(lines[k][1])))
                k += 1
                continue
            removed, added = [], []
            while k < len(lines) and lines[k][0] == "-":
                removed.append(lines[k][1])
                k += 1
            while k < len(lines) and lines[k][0] == "+":
                added.append(lines[k][1])
                k += 1
            rows += _change_rows(removed, added, stats)
    if file["binary"]:
        rows.append('<div class="note">Binary file changed</div>')
    elif not rows:
        note = "Renamed, content unchanged" if file["status"] == "renamed" else "No content changes"
        rows.append(f'<div class="note">{note}</div>')
    path = file["path"]
    directory, _, name = path.rpartition("/")
    shown = (f'<span class="dir">{html.escape(directory)}/</span>' if directory else "") + html.escape(name)
    if file["status"] == "renamed" and file["old"] != path:
        shown = f'<span class="dir">{html.escape(file["old"])} →</span> {shown}'
    badge = {"added": "new", "deleted": "deleted", "renamed": "renamed"}.get(file["status"])
    badge_html = f'<span class="badge {file["status"]}">{badge}</span>' if badge else ""
    return (f'<details class="file"{" open" if open_ else ""}><summary>{badge_html}'
            f'<span class="path">{shown}</span>{_stat(stats)}</summary>'
            f'<div class="diff">{"".join(rows)}</div></details>')


def _stat(stats):
    parts = []
    if stats["added"]:
        parts.append(f'<span class="a" title="lines added">+{stats["added"]}</span>')
    if stats["removed"]:
        parts.append(f'<span class="r" title="lines removed">−{stats["removed"]}</span>')
    if stats["done"]:
        parts.append(f'<span class="t" title="tasks completed">✓{stats["done"]}</span>')
    if other := stats["tasks"] - stats["done"]:
        parts.append(f'<span class="t" title="other task status changes">☐{other}</span>')
    return '<span class="stat">' + " ".join(parts) + "</span>"


def _when(iso):
    moment = datetime.fromisoformat(iso)
    return moment.strftime("%a %d %b %Y"), moment.strftime("%H:%M")


def _plural(count, word):
    return f"{count} {word}{'' if count == 1 else 's'}"


def _title(meta):
    if meta["hermes"] or not SNAPSHOT_SUBJECT.fullmatch(meta["subject"]):
        return meta["subject"]
    files = meta["files"]
    if not files:
        return "No file changes"
    names = [Path(f).name.removesuffix(".md") for f in files[:3]]
    return ", ".join(names) + (f" +{len(files) - 3} more" if len(files) > 3 else "")


def _badge(meta):
    return '<span class="badge hermes">Hermes</span>' if meta["hermes"] else '<span class="badge">Snapshot</span>'


def _render_commit(git_bin, repo, work_tree, output, commit, date, parents, subject, hermes):
    patch = _git(git_bin, repo, work_tree, "show", "--format=", "--patch", "-M", "--no-color",
                 "--no-ext-diff", "--no-textconv", commit)
    raw = _git(git_bin, repo, work_tree, "show", "--format=fuller", "--stat", "--summary", "--no-color", commit)
    files, truncated = _parse_patch(patch)
    meta = {"v": VERSION, "date": date, "subject": subject, "hermes": hermes,
            "files": [f["path"] for f in files], "added": 0, "removed": 0, "tasks": 0, "done": 0}
    sections = []
    for file in files:
        stats = {"added": 0, "removed": 0, "tasks": 0, "done": 0}
        size = sum(len(h["lines"]) for h in file["hunks"])
        sections.append(_file_html(file, stats, open_=size <= 300 and len(files) <= 30))
        for key in stats:
            meta[key] += stats[key]
    day, time = _when(date)
    summary = [f"{day} · {time}", _plural(len(files), "file")]
    if lines := " ".join(f"{sign}{meta[key]}" for sign, key in (("+", "added"), ("−", "removed")) if meta[key]):
        summary.append(f"{lines} lines")
    if meta["done"]:
        summary.append(f"{_plural(meta['done'], 'task')} done")
    if meta["tasks"] - meta["done"]:
        summary.append(f"{_plural(meta['tasks'] - meta['done'], 'task')} changed status")
    if truncated:
        sections.append('<p class="note">Diff truncated; see the full change with vault-git.</p>')
    parent = parents.split()[0] if parents else None
    footer = (f'<nav class="pager"><a href="{parent}.html">← Previous '
              f'{"Hermes save" if hermes else "snapshot"}</a></nav>') if parent else ""
    body = (f'<nav><a href="index.html">← All changes</a> · <a href="hermes.html">Hermes saves</a></nav>'
            f'{_badge(meta)}<h1>{html.escape(_title(meta))}</h1>'
            f'<p class="meta">{html.escape(" · ".join(summary))}</p>'
            + "".join(sections) + footer
            + f'<details class="raw"><summary>Git details</summary><pre>{html.escape(raw)}</pre></details>')
    _write_atomic(output / f"{commit}.html", _page(_title(meta), body))
    _write_atomic(output / f"{commit}.json", json.dumps(meta))
    return meta


def _load_meta(path):
    try:
        meta = json.loads(path.read_text())
    except (OSError, ValueError):
        return None
    return meta if meta.get("v") == VERSION else None


def _write_lists(output, entries, first, prefix, tab):
    """Paginated commit lists grouped by day; returns the file names written."""
    written = []
    tabs = (f'<nav class="tabs"><a href="index.html"{" class=on" if tab == "all" else ""}>All changes</a>'
            f'<a href="hermes.html"{" class=on" if tab == "hermes" else ""}>Hermes saves</a></nav>')
    for start in range(0, max(1, len(entries)), PAGE_SIZE):
        number = start // PAGE_SIZE + 1
        name = lambda n: f"{first}.html" if n == 1 else f"{prefix}-{n}.html"
        body, day = ["<h1>Vault changes</h1>", tabs], None
        if not entries:
            body.append('<p class="meta">No changes yet.</p>')
        for commit, meta in entries[start:start + PAGE_SIZE]:
            entry_day, time = _when(meta["date"])
            if entry_day != day:
                body.append(("</ul>" if day else "") + f'<h2 class="day">{entry_day}</h2><ul class="log">')
                day = entry_day
            files = ""
            if meta["hermes"] and meta["files"]:
                files = f'<span class="files">{html.escape(", ".join(meta["files"]))}</span>'
            body.append(f'<li><a href="{commit}.html"><span class="time">{time}</span>{_badge(meta)}'
                        f'<span class="title">{html.escape(_title(meta))}</span>{_stat(meta)}{files}</a></li>')
        if day:
            body.append("</ul>")
        newer = f'<a href="{name(number - 1)}">← Newer</a>' if number > 1 else "<span></span>"
        older = f'<a href="{name(number + 1)}">Older →</a>' if start + PAGE_SIZE < len(entries) else ""
        body.append(f'<nav class="pager">{newer}{older}</nav>')
        _write_atomic(output / name(number), _page("Vault changes", "".join(body)))
        written.append(name(number))
    return written


def render(repo, work_tree, output, git_bin="git"):
    repo, work_tree, output = Path(repo), Path(work_tree), Path(output)
    output.mkdir(parents=True, exist_ok=True)
    hermes_commits = set()
    if subprocess.run([git_bin, f"--git-dir={repo}", "show-ref", "--verify", "--quiet", HERMES_REF],
                      check=False).returncode == 0:
        hermes_commits = set(_git(git_bin, repo, work_tree, "rev-list", HERMES_REF).split())
    # NUL-separated: subjects may contain Unicode line separators that splitlines() would break on
    fields = _git(git_bin, repo, work_tree, "log", "-z", "--all", "--date-order",
                  "--format=%H%x00%aI%x00%P%x00%s").split("\0")
    entries = []
    for index in range(0, len(fields) - 3, 4):
        commit, date, parents, subject = fields[index:index + 4]
        meta = _load_meta(output / f"{commit}.json")
        if meta is None or not (output / f"{commit}.html").exists():
            meta = _render_commit(git_bin, repo, work_tree, output, commit, date, parents, subject,
                                  commit in hermes_commits)
        entries.append((commit, meta))
    written = _write_lists(output, entries, "index", "page", "all")
    written += _write_lists(output, [e for e in entries if e[1]["hermes"]], "hermes", "hermes", "hermes")
    for stale in [*output.glob("page-*.html"), *output.glob("hermes-*.html")]:
        if stale.name not in written:
            stale.unlink()


def commit_hermes(repo, work_tree, message, author_email, git_bin="git"):
    """Commit Hermes/ to an independent branch, preserving hourly full-vault history."""
    repo, work_tree = Path(repo), Path(work_tree)
    ref = "refs/heads/hermes"
    git_base = [git_bin, f"--git-dir={repo}", f"--work-tree={work_tree}"]
    exists = subprocess.run([*git_base, "show-ref", "--verify", "--quiet", ref], check=False)
    if exists.returncode not in (0, 1):
        exists.check_returncode()
    parent = _git(git_bin, repo, work_tree, "rev-parse", ref).strip() if exists.returncode == 0 else None
    if not parent and not any(path.is_file() or path.is_symlink()
                              for path in (work_tree / "Hermes").rglob("*")):
        return None
    with tempfile.NamedTemporaryFile(dir=repo, prefix=".hermes-index-", delete=False) as index:
        index_path = Path(index.name)
    index_path.unlink()
    env = os.environ.copy()
    env["GIT_INDEX_FILE"] = str(index_path)
    env.update({
        "GIT_AUTHOR_NAME": "vault-snapshot",
        "GIT_AUTHOR_EMAIL": author_email,
        "GIT_COMMITTER_NAME": "vault-snapshot",
        "GIT_COMMITTER_EMAIL": author_email,
    })
    try:
        _git(git_bin, repo, work_tree, "read-tree", parent if parent else "--empty", env=env)
        _git(git_bin, repo, work_tree, "add", "-A", "--", "Hermes/", env=env)
        tree = _git(git_bin, repo, work_tree, "write-tree", env=env).strip()
        if parent and tree == _git(git_bin, repo, work_tree, "rev-parse", f"{parent}^{{tree}}", env=env).strip():
            return None
        commit_args = ["commit-tree", tree]
        if parent:
            commit_args.extend(["-p", parent])
        commit = _git(git_bin, repo, work_tree, *commit_args, "-m", message, env=env).strip()
        update_args = ["update-ref", ref, commit]
        if parent:
            update_args.append(parent)
        _git(git_bin, repo, work_tree, *update_args, env=env)
        return commit
    finally:
        index_path.unlink(missing_ok=True)


def make_server(host, port, directory, username, password):
    expected = f"{username}:{password}".encode("utf-8")

    class Handler(SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=str(directory), **kwargs)

        def _authorized(self):
            scheme, _, token = self.headers.get("Authorization", "").partition(" ")
            if scheme.lower() != "basic":
                return False
            try:
                supplied = base64.b64decode(token, validate=True)
            except (binascii.Error, ValueError):
                return False
            return hmac.compare_digest(supplied, expected)

        def _respond(self, method):
            if not self._authorized():
                self.send_response(401)
                self.send_header("WWW-Authenticate", 'Basic realm="Vault history"')
                self.send_header("Content-Length", "0")
                self.end_headers()
                return
            method()

        def do_GET(self):
            self._respond(super().do_GET)

        def do_HEAD(self):
            self._respond(super().do_HEAD)

        def list_directory(self, path):
            self.send_error(404)
            return None

        def end_headers(self):
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header("Referrer-Policy", "no-referrer")
            self.send_header("Content-Security-Policy", "default-src 'none'; style-src 'unsafe-inline'")
            super().end_headers()

    return ThreadingHTTPServer((host, port), Handler)


def main():
    parser = argparse.ArgumentParser()
    subcommands = parser.add_subparsers(dest="command", required=True)
    render_command = subcommands.add_parser("render")
    render_command.add_argument("repo")
    render_command.add_argument("work_tree")
    render_command.add_argument("output")
    render_command.add_argument("--git-bin", default="git")
    commit_command = subcommands.add_parser("commit-hermes")
    commit_command.add_argument("repo")
    commit_command.add_argument("work_tree")
    commit_command.add_argument("message")
    commit_command.add_argument("author_email")
    commit_command.add_argument("--git-bin", default="git")
    serve_command = subcommands.add_parser("serve")
    serve_command.add_argument("directory")
    serve_command.add_argument("--port", type=int, default=9121)
    args = parser.parse_args()
    if args.command == "render":
        render(args.repo, args.work_tree, args.output, args.git_bin)
    elif args.command == "commit-hermes":
        commit_hermes(args.repo, args.work_tree, args.message, args.author_email, args.git_bin)
    else:
        with make_server("127.0.0.1", args.port, args.directory,
                         os.environ["HERMES_DASHBOARD_BASIC_AUTH_USERNAME"],
                         os.environ["HERMES_DASHBOARD_BASIC_AUTH_PASSWORD"]) as server:
            server.serve_forever()


if __name__ == "__main__":
    main()
