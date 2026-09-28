"""Render vault Git history as static pages and serve them with Basic Auth."""

import argparse
import base64
import binascii
import html
import hmac
import os
import subprocess
import tempfile
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


STYLE = """body{font:16px system-ui,sans-serif;max-width:1100px;margin:2rem auto;padding:0 1rem;color:#ddd;background:#16191d}
a{color:#8dc8ff}li{margin:.6rem 0}pre{overflow:auto;padding:1rem;background:#22272d;border-radius:.5rem;line-height:1.35}
small{color:#aaa}nav{margin:1rem 0}h1{font-size:1.6rem}"""
PAGE_SIZE = 100


def _git(git_bin, repo, work_tree, *args, env=None):
    result = subprocess.run(
        [git_bin, f"--git-dir={repo}", f"--work-tree={work_tree}", *args],
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


def render(repo, work_tree, output, git_bin="git"):
    repo, work_tree, output = Path(repo), Path(work_tree), Path(output)
    output.mkdir(parents=True, exist_ok=True)
    commits = [line.split("\0", 1) for line in
               _git(git_bin, repo, work_tree, "log", "--all", "--format=%H%x00%s").splitlines()
               if line]
    entries = []
    for commit, subject in commits:
        page_path = output / f"{commit}.html"
        if not page_path.exists():
            diff = _git(git_bin, repo, work_tree, "show", "--format=fuller", "--no-ext-diff", "--no-textconv", commit)
            _write_atomic(
                page_path,
                _page(subject, f'<nav><a href="index.html">All snapshots</a></nav>'
                      f'<h1>{html.escape(subject)}</h1><pre>{html.escape(diff)}</pre>'),
            )
        entries.append(f'<li><a href="{commit}.html">{html.escape(subject)}</a> '
                       f'<small>{commit[:12]}</small></li>')
    latest = ""
    if commits:
        diff = _git(git_bin, repo, work_tree, "show", "--format=fuller", "--no-ext-diff", "--no-textconv", commits[0][0])
        latest = f"<h2>Latest snapshot</h2><pre>{html.escape(diff)}</pre>"
    for start in range(0, max(1, len(entries)), PAGE_SIZE):
        number = start // PAGE_SIZE + 1
        filename = "index.html" if number == 1 else f"page-{number}.html"
        navigation = []
        if number > 1:
            previous = "index.html" if number == 2 else f"page-{number - 1}.html"
            navigation.append(f'<a href="{previous}">Newer</a>')
        if start + PAGE_SIZE < len(entries):
            navigation.append(f'<a href="page-{number + 1}.html">Older</a>')
        body = "<h1>Vault diffs</h1>" + (latest if number == 1 else "")
        body += f"<h2>All snapshots · page {number}</h2><ol start=\"{start + 1}\">"
        body += "".join(entries[start:start + PAGE_SIZE]) + "</ol>"
        body += "<nav>" + " · ".join(navigation) + "</nav>"
        _write_atomic(output / filename, _page("Vault diffs", body))


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
