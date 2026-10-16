"""Archive Cloudflare's per-request analytics before Cloudflare drops them.

Cloudflare keeps the sampled per-request datasets (httpRequestsAdaptive,
firewallEventsAdaptive) for about 31 days. Each run copies every complete UTC
hour still inside that window and not yet on disk:

    <dataDir>/<zone>/<dataset>/YYYY/MM/DD/HH.ndjson.gz   one JSON row per line
    <dataDir>/<zone>/<dataset>/YYYY/MM/DD/manifest.json  rows + Cloudflare's estimate per hour

Rows are as sampled by Cloudflare: http rows carry no sample interval, so the
manifest keeps Cloudflare's estimated request count next to the row count.
After ipRetentionDays, clientIP is replaced by a keyed hash plus its /24 (IPv4)
or /48 (IPv6) network, and the file becomes HH.anon.ndjson.gz.

    cloudflare-archive --config FILE run      fetch missing hours, anonymize old ones
    cloudflare-archive --config FILE status   coverage and size per zone/dataset
"""
import argparse
import datetime as dt
import gzip
import hashlib
import hmac
import ipaddress
import json
import os
import secrets
import sys
import time
import urllib.error
import urllib.request

UTC = dt.timezone.utc
HOUR = dt.timedelta(hours=1)
PAGE = 10000  # Cloudflare's maxPageSize for both datasets

DATASETS = {
    "http": {
        "node": "httpRequestsAdaptive",
        # rows of the groups node are weighted by sampleInterval: rows = count / sampleInterval
        "groups": "httpRequestsAdaptiveGroups",
        "fields": (
            "datetime rayName clientIP clientAsn clientASNDescription clientCountryName clientDeviceType "
            "clientRequestHTTPHost clientRequestHTTPMethodName clientRequestHTTPProtocol clientRequestScheme "
            "clientRequestPath clientRequestQuery clientSSLProtocol httpApplicationVersion edgeResponseStatus "
            "edgeResponseContentTypeName cacheStatus originResponseStatus originResponseDurationMs "
            "originResponseHeaderReceiveDurationMs originTcpHandshakeDurationMs originTlsHandshakeDurationMs "
            "requestSource securityAction securitySource userAgent userAgentBrowser userAgentOS verifiedBotCategory "
            "sessionIdHash leakedCredentialCheckResult payPerCrawlStatus zoneVersion"
        ),
    },
    "firewall": {
        "node": "firewallEventsAdaptive",
        "groups": None,  # not available on the Free plan; rows carry their own sampleInterval
        "fields": (
            "datetime rayName originatorRayName action source kind description ruleId rulesetId ref matchIndex "
            "sampleInterval clientIP clientIPClass clientAsn clientASNDescription clientCountryName "
            "clientRequestHTTPHost clientRequestHTTPMethodName clientRequestHTTPProtocol clientRequestScheme "
            "clientRequestPath clientRequestQuery clientRefererScheme clientRefererHost clientRefererPath "
            "clientRefererQuery edgeColoName edgeResponseStatus originResponseStatus userAgent verifiedBotCategory "
            "httpApplicationVersion leakedCredentialCheckResult zoneVersion"
        ),
    },
}


class RateLimited(Exception):
    pass


class Incomplete(Exception):
    """Cloudflare returned fewer rows than it counts for the hour (data may still be arriving)."""


def log(msg):
    print(msg, flush=True)


def iso(t):
    return t.strftime("%Y-%m-%dT%H:%M:%SZ")


class Cloudflare:
    def __init__(self, endpoint, token, pause):
        self.endpoint = endpoint
        self.token = token
        self.pause = pause
        self.queries = 0

    def query(self, query, variables):
        """POST a GraphQL query; waits out rate limits and retries transient errors."""
        body = json.dumps({"query": query, "variables": variables}).encode()
        for attempt in range(1, 7):
            time.sleep(self.pause)
            self.queries += 1
            req = urllib.request.Request(self.endpoint, data=body, headers={
                "Authorization": f"Bearer {self.token}",
                "Content-Type": "application/json",
            })
            try:
                with urllib.request.urlopen(req, timeout=120) as resp:
                    payload = json.load(resp)
            except urllib.error.HTTPError as e:
                if e.code in (401, 403):
                    raise SystemExit(f"Cloudflare rejected the token (HTTP {e.code}); it needs Zone > Analytics > Read")
                if e.code != 429 and e.code < 500:
                    raise
                wait = 300 if e.code == 429 else 30 * attempt
            except (urllib.error.URLError, TimeoutError, ConnectionError) as e:
                log(f"network error ({e}), retry {attempt}")
                wait = 30 * attempt
            else:
                errors = payload.get("errors") or []
                if not errors:
                    return payload["data"]
                text = "; ".join(str(err.get("message")) for err in errors)
                if "rate limit" not in text.lower() and "budget" not in text.lower():
                    raise RuntimeError(text)
                wait = 300
            log(f"waiting {wait}s before retry {attempt}")
            time.sleep(wait)
        raise RateLimited("Cloudflare kept rate limiting or failing")


def fetch_rows(cf, zone_id, ds, start, end):
    """All rows in [start, end); windows that fill a page are split in half."""
    q = (f'query($z:String!,$s:Time!,$e:Time!){{viewer{{zones(filter:{{zoneTag:$z}}){{'
         f'rows: {ds["node"]}(limit:{PAGE}, orderBy:[datetime_ASC], filter:{{datetime_geq:$s, datetime_lt:$e}}){{{ds["fields"]}}}'
         f'}}}}}}')
    rows = cf.query(q, {"z": zone_id, "s": iso(start), "e": iso(end)})["viewer"]["zones"][0]["rows"]
    if len(rows) < PAGE:
        return rows
    if end - start <= dt.timedelta(seconds=1):
        raise RuntimeError(f"more than {PAGE} rows in the second starting {iso(start)}")
    mid = start + dt.timedelta(seconds=(end - start).total_seconds() // 2)
    return fetch_rows(cf, zone_id, ds, start, mid) + fetch_rows(cf, zone_id, ds, mid, end)


def expected(cf, zone_id, ds, start, end):
    """(rows, estimated requests) Cloudflare holds for the window, or (None, None) without a groups node."""
    if not ds["groups"]:
        return None, None
    q = (f'query($z:String!,$s:Time!,$e:Time!){{viewer{{zones(filter:{{zoneTag:$z}}){{'
         f'g: {ds["groups"]}(limit:1000, filter:{{datetime_geq:$s, datetime_lt:$e}}){{count dimensions{{sampleInterval}}}}'
         f'}}}}}}')
    groups = cf.query(q, {"z": zone_id, "s": iso(start), "e": iso(end)})["viewer"]["zones"][0]["g"]
    rows = sum(round(g["count"] / g["dimensions"]["sampleInterval"]) for g in groups)
    return rows, sum(g["count"] for g in groups)


def day_dir(root, zone, dataset, hour):
    return os.path.join(root, zone, dataset, hour.strftime("%Y/%m/%d"))


def hour_files(root, zone, dataset, hour):
    d = day_dir(root, zone, dataset, hour)
    h = hour.strftime("%H")
    return os.path.join(d, f"{h}.ndjson.gz"), os.path.join(d, f"{h}.anon.ndjson.gz")


def write_atomic(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = f"{path}.tmp"
    with open(tmp, "wb") as f:
        f.write(data)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, path)


def write_rows(path, rows):
    lines = "".join(json.dumps(r, separators=(",", ":"), ensure_ascii=False) + "\n" for r in rows)
    write_atomic(path, gzip.compress(lines.encode(), compresslevel=9, mtime=0))


def read_rows(path):
    with gzip.open(path, "rt", encoding="utf-8") as f:
        return [json.loads(line) for line in f if line.strip()]


def read_manifest(root, zone, dataset, hour):
    try:
        with open(os.path.join(day_dir(root, zone, dataset, hour), "manifest.json")) as f:
            return json.load(f)
    except FileNotFoundError:
        return {}


def update_manifest(root, zone, dataset, hour, entry):
    path = os.path.join(day_dir(root, zone, dataset, hour), "manifest.json")
    manifest = read_manifest(root, zone, dataset, hour)
    manifest[hour.strftime("%H")] = entry
    write_atomic(path, (json.dumps(manifest, indent=1, sort_keys=True) + "\n").encode())


def archive_hour(cf, cfg, zone, dataset, hour, keep_incomplete):
    """Fetch and store one hour. An incomplete hour is only stored when keep_incomplete
    (it is about to leave Cloudflare's window), flagged in the manifest."""
    ds = DATASETS[dataset]
    raw, _ = hour_files(cfg["dataDir"], zone["name"], dataset, hour)
    want_rows, estimate = expected(cf, zone["id"], ds, hour, hour + HOUR)
    rows = fetch_rows(cf, zone["id"], ds, hour, hour + HOUR)
    entry = {"rows": len(rows), "fetchedAt": iso(dt.datetime.now(UTC))}
    if want_rows is not None and len(rows) != want_rows:
        problem = f"got {len(rows)} rows, Cloudflare counts {want_rows}"
        if not keep_incomplete:
            raise Incomplete(problem)
        entry["incomplete"] = problem
    entry["estimatedRequests"] = estimate if estimate is not None else sum(r.get("sampleInterval") or 1 for r in rows)
    write_rows(raw, rows)
    update_manifest(cfg["dataDir"], zone["name"], dataset, hour, entry)
    if "incomplete" in entry:
        raise Incomplete(f"{entry['incomplete']}; stored anyway, flagged in manifest.json")
    return len(rows)


def ip_key(cfg):
    path = os.path.join(cfg["dataDir"], ".ip-hash-key")
    try:
        with open(path, "rb") as f:
            return f.read()
    except FileNotFoundError:
        key = secrets.token_bytes(32)
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o400)
        with os.fdopen(fd, "wb") as f:
            f.write(key)
        log(f"created {path}: keep it with the archive, hashes only match across files made with the same key")
        return key


def anonymize_ip(key, value):
    if not value:
        return value, value
    digest = hmac.new(key, value.encode(), hashlib.sha256).hexdigest()[:24]
    try:
        ip = ipaddress.ip_address(value)
        prefix = 24 if ip.version == 4 else 48
        net = str(ipaddress.ip_network(f"{value}/{prefix}", strict=False))
    except ValueError:
        net = None
    return digest, net


def anonymize_file(key, raw, anon):
    rows = read_rows(raw)
    for r in rows:
        r["clientIPHash"], r["clientIPNet"] = anonymize_ip(key, r.pop("clientIP", None))
    write_rows(anon, rows)
    os.remove(raw)


def hours_back(now, days, lag_hours):
    """Complete UTC hours still inside Cloudflare's retention, newest first."""
    last = (now - dt.timedelta(hours=lag_hours)).replace(minute=0, second=0, microsecond=0) - HOUR
    first = (now - dt.timedelta(days=days)).replace(minute=0, second=0, microsecond=0) + HOUR
    hours = []
    while last >= first:
        hours.append(last)
        last -= HOUR
    return hours


def run(cfg):
    token = open(cfg["tokenFile"]).read().strip()
    cf = Cloudflare(cfg.get("endpoint", "https://api.cloudflare.com/client/v4/graphql"), token, cfg.get("pause", 0.5))
    now = dt.datetime.now(UTC)
    hours = hours_back(now, cfg["days"], cfg["lagHours"])
    failures, fetched, alert_before = [], 0, now - dt.timedelta(days=cfg["alertMissingDays"])

    for zone in cfg["zones"]:
        for dataset in cfg["datasets"]:
            # oldest first: those are the next ones Cloudflare deletes
            for hour in reversed(hours):
                raw, anon = hour_files(cfg["dataDir"], zone["name"], dataset, hour)
                # a copy flagged incomplete is fetched again while Cloudflare still has the hour:
                # mismatches are usually transient (heavy hours under load) and gone on a later run
                flagged = os.path.exists(raw) and "incomplete" in read_manifest(
                    cfg["dataDir"], zone["name"], dataset, hour).get(hour.strftime("%H"), {})
                if (os.path.exists(raw) or os.path.exists(anon)) and not flagged:
                    continue
                label = f'{zone["name"]} {dataset} {iso(hour)}'
                old = hour < alert_before
                try:
                    n = archive_hour(cf, cfg, zone, dataset, hour, keep_incomplete=old and not flagged)
                    fetched += 1
                    log(f"{label}: {n} rows" + (", replaces the copy flagged incomplete" if flagged else ""))
                except Incomplete as e:
                    # recent hours can still be filling in; an old incomplete hour is a real problem,
                    # reported once when first stored
                    if flagged:
                        log(f"{label}: still {e}, keeping the flagged copy")
                        continue
                    log(f"{label}: {e}" + ("" if old else ", will retry next run"))
                    if old:
                        failures.append(f"{label}: {e}")
                except RateLimited as e:
                    failures.append(f"{label}: {e}")
                    log(f"{label}: {e}; stopping this run")
                    return finish(cf, fetched, failures + ["run stopped early"])
                except Exception as e:  # noqa: BLE001 - one bad hour must not stop the others
                    failures.append(f"{label}: {e}")
                    log(f"{label}: FAILED {e}")

    anonymized = anonymize_old(cfg, now)
    if anonymized:
        log(f"anonymized IPs in {anonymized} file(s) older than {cfg['ipRetentionDays']} days")
    return finish(cf, fetched, failures)


def anonymize_old(cfg, now):
    cutoff = now - dt.timedelta(days=cfg["ipRetentionDays"])
    key, count = None, 0
    for dirpath, _, files in os.walk(cfg["dataDir"]):
        for name in sorted(files):
            if not name.endswith(".ndjson.gz") or name.endswith(".anon.ndjson.gz"):
                continue
            parts = os.path.relpath(os.path.join(dirpath, name), cfg["dataDir"]).split(os.sep)
            # <zone>/<dataset>/YYYY/MM/DD/HH.ndjson.gz
            hour = dt.datetime(int(parts[-4]), int(parts[-3]), int(parts[-2]), int(name[:2]), tzinfo=UTC)
            if hour >= cutoff:
                continue
            key = key or ip_key(cfg)
            raw = os.path.join(dirpath, name)
            anonymize_file(key, raw, raw.replace(".ndjson.gz", ".anon.ndjson.gz"))
            count += 1
    return count


def finish(cf, fetched, failures):
    log(f"archived {fetched} hour(s) with {cf.queries} queries")
    if failures:
        log(f"{len(failures)} problem(s):")
        for f in failures:
            log(f"  {f}")
        return 1
    return 0


def status(cfg):
    now = dt.datetime.now(UTC)
    window = hours_back(now, cfg["days"], cfg["lagHours"])
    for zone in cfg["zones"]:
        for dataset in cfg["datasets"]:
            base = os.path.join(cfg["dataDir"], zone["name"], dataset)
            files, size, oldest, flagged = 0, 0, None, 0
            for dirpath, _, names in os.walk(base):
                for name in names:
                    if name.endswith(".ndjson.gz"):
                        files += 1
                        size += os.path.getsize(os.path.join(dirpath, name))
                        oldest = min(oldest or dirpath, dirpath)
                    elif name == "manifest.json":
                        with open(os.path.join(dirpath, name)) as f:
                            flagged += sum("incomplete" in e for e in json.load(f).values())
            missing = [h for h in window if not any(os.path.exists(p) for p in hour_files(cfg["dataDir"], zone["name"], dataset, h))]
            first_day = os.path.relpath(oldest, base) if oldest else "-"
            log(f'{zone["name"]:<22} {dataset:<9} {files:>6} hours since {first_day}  {size / 1e6:8.1f} MB  '
                f'flagged incomplete: {flagged}  '
                f'missing in Cloudflare window: {len(missing)}' + (f' (oldest {iso(missing[-1])})' if missing else ""))
    return 0


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--config", required=True)
    p.add_argument("command", choices=["run", "status"])
    args = p.parse_args()
    with open(args.config) as f:
        cfg = json.load(f)
    cfg["tokenFile"] = os.path.expandvars(cfg.get("tokenFile", ""))
    unknown = set(cfg["datasets"]) - set(DATASETS)
    if unknown:
        raise SystemExit(f"unknown datasets: {sorted(unknown)}")
    os.umask(0o027)
    return run(cfg) if args.command == "run" else status(cfg)


if __name__ == "__main__":
    sys.exit(main())
