import base64
import importlib.util
import json
import subprocess
import sys
import tempfile
import threading
import unittest
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen


MODULE = Path(__file__).resolve().parents[1] / "vault_history.py"
spec = importlib.util.spec_from_file_location("vault_history", MODULE)
vault_history = importlib.util.module_from_spec(spec)
spec.loader.exec_module(vault_history)


class VaultHistoryTests(unittest.TestCase):
    def test_first_custom_commit_is_noop_when_hermes_directory_is_empty(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo = root / "vault.git"
            work_tree = root / "vault"
            work_tree.mkdir()
            subprocess.run(["git", "init", "-q", "--bare", str(repo)], check=True)

            result = vault_history.commit_hermes(repo, work_tree, "No changes", "test@example.org")

            self.assertIsNone(result)

    def test_custom_hermes_commit_survives_hourly_full_vault_snapshot(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo = root / "vault.git"
            work_tree = root / "vault"
            (work_tree / "Hermes").mkdir(parents=True)
            (work_tree / "Hermes" / "note.md").write_text("first\n")
            subprocess.run(["git", "init", "-q", "--bare", str(repo)], check=True)
            git = ["git", f"--git-dir={repo}", f"--work-tree={work_tree}"]
            identity = ["-c", "user.name=Test", "-c", "user.email=test@example.org"]
            subprocess.run([*git, "add", "-A"], check=True)
            subprocess.run([*git, *identity, "commit", "-qm", "snapshot"], check=True)
            (work_tree / "Hermes" / "note.md").write_text("second\n")
            subprocess.run([*git, "add", "-A"], check=True)
            subprocess.run([*git, *identity, "commit", "-qm", "snapshot during edit"], check=True)
            main_head = subprocess.check_output([*git, "rev-parse", "HEAD"])

            vault_history.commit_hermes(repo, work_tree, "Finish note", "test@example.org")

            self.assertEqual(subprocess.check_output([*git, "rev-parse", "HEAD"]), main_head)
            subject = subprocess.check_output([*git, "log", "-1", "--format=%s", "refs/heads/hermes"])
            self.assertEqual(subject, b"Finish note\n")
            patch = subprocess.check_output([*git, "show", "refs/heads/hermes"])
            self.assertIn(b"+second", patch)
            (work_tree / "Hermes" / "note.md").write_text("third\n")
            vault_history.commit_hermes(repo, work_tree, "Revise note", "test@example.org")
            later_patch = subprocess.check_output([*git, "show", "refs/heads/hermes"])
            self.assertIn(b"-second", later_patch)
            self.assertIn(b"+third", later_patch)
            (work_tree / "Hermes" / "note.md").write_text("fourth\n")
            subprocess.run([
                sys.executable, str(MODULE), "commit-hermes", "--git-bin", "git", "--",
                str(repo), str(work_tree), "-h", "test@example.org",
            ], check=True)
            self.assertEqual(
                subprocess.check_output([*git, "log", "-1", "--format=%s", "refs/heads/hermes"]),
                b"-h\n",
            )
            output = root / "pages"
            vault_history.render(repo, work_tree, output)
            index = (output / "index.html").read_text()
            self.assertIn("Finish note", index)
            self.assertIn("snapshot during edit", index)
            hermes = (output / "hermes.html").read_text()
            self.assertIn("Finish note", hermes)
            self.assertNotIn("snapshot during edit", hermes)

    def test_empty_snapshot_repo_has_a_viewable_index(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo = root / "vault"
            repo.mkdir()
            subprocess.run(["git", "init", "-q", str(repo)], check=True)
            output = root / "pages"

            vault_history.render(repo / ".git", repo, output)

            self.assertIn("No changes yet", (output / "index.html").read_text())

    def test_renderer_shows_all_commits_and_escapes_note_content(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo = root / "vault"
            repo.mkdir()
            subprocess.run(["git", "init", "-q", str(repo)], check=True)
            subprocess.run(["git", "-C", str(repo), "config", "user.name", "Test"], check=True)
            subprocess.run(["git", "-C", str(repo), "config", "user.email", "test@example.org"], check=True)
            (repo / "private.md").write_text("<script>alert(1)</script>\n")
            subprocess.run(["git", "-C", str(repo), "add", "."], check=True)
            subprocess.run(["git", "-C", str(repo), "commit", "-qm", "first <note>"], check=True)
            (repo / "private.md").unlink()
            subprocess.run(["git", "-C", str(repo), "add", "-A"], check=True)
            subprocess.run(["git", "-C", str(repo), "commit", "-qm", "deleted note"], check=True)

            output = root / "pages"
            vault_history.render(repo / ".git", repo, output)

            index = (output / "index.html").read_text()
            self.assertIn("deleted note", index)
            self.assertIn("first &lt;note&gt;", index)
            self.assertNotIn("<script>", index)
            pages = [p for p in output.glob("*.html") if p.stem not in ("index", "hermes")]
            self.assertEqual(len(pages), 2)
            self.assertTrue(any("&lt;script&gt;alert(1)&lt;/script&gt;" in p.read_text() for p in pages))

    def test_history_index_has_recent_page_and_link_to_older_commits(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo = root / "vault"
            repo.mkdir()
            subprocess.run(["git", "init", "-q", str(repo)], check=True)
            subprocess.run(["git", "-C", str(repo), "config", "user.name", "Test"], check=True)
            subprocess.run(["git", "-C", str(repo), "config", "user.email", "test@example.org"], check=True)
            for number in range(101):
                (repo / "note.md").write_text(f"version {number}\n")
                subprocess.run(["git", "-C", str(repo), "add", "note.md"], check=True)
                subprocess.run(["git", "-C", str(repo), "commit", "-qm", f"snapshot {number:03d}"], check=True)

            output = root / "pages"
            vault_history.render(repo / ".git", repo, output)

            recent = (output / "index.html").read_text()
            older = (output / "page-2.html").read_text()
            self.assertIn("snapshot 100", recent)
            self.assertNotIn("snapshot 000", recent)
            self.assertIn('href="page-2.html"', recent)
            self.assertIn("snapshot 000", older)
            self.assertIn('href="index.html"', older)

    def test_commit_page_highlights_edits_and_collapses_task_toggles(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo = root / "vault"
            repo.mkdir()
            subprocess.run(["git", "init", "-q", str(repo)], check=True)
            subprocess.run(["git", "-C", str(repo), "config", "user.name", "Test"], check=True)
            subprocess.run(["git", "-C", str(repo), "config", "user.email", "test@example.org"], check=True)
            note = repo / "todo.md"
            note.write_text("- [ ] Call Marco\nThe plant is 5 MW.\nOld line\n")
            subprocess.run(["git", "-C", str(repo), "add", "."], check=True)
            subprocess.run(["git", "-C", str(repo), "commit", "-qm", "first"], check=True)
            note.write_text("- [x] Call Marco ✅ 2026-09-29\nThe plant is 6 MW.\n")
            subprocess.run(["git", "-C", str(repo), "commit", "-qam", "second"], check=True)
            head = subprocess.check_output(["git", "-C", str(repo), "rev-parse", "HEAD"], text=True).strip()

            output = root / "pages"
            vault_history.render(repo / ".git", repo, output)

            page = (output / f"{head}.html").read_text()
            self.assertIn('class="l task"', page)
            self.assertIn('<span class="pill">done</span>', page)
            self.assertEqual(page.count("Call Marco"), 1)  # one task row, not a -/+ pair
            self.assertIn("<del>5</del><ins>6</ins>", page)
            self.assertIn('<div class="l del"><span class="s">−</span><span class="c">Old line</span>', page)
            self.assertIn('<details class="raw">', page)
            self.assertIn("+1 −2 lines · 1 task done", page)

    def test_outdated_cached_pages_are_rerendered(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo = root / "vault"
            repo.mkdir()
            subprocess.run(["git", "init", "-q", str(repo)], check=True)
            subprocess.run(["git", "-C", str(repo), "config", "user.name", "Test"], check=True)
            subprocess.run(["git", "-C", str(repo), "config", "user.email", "test@example.org"], check=True)
            (repo / "note.md").write_text("hello\n")
            subprocess.run(["git", "-C", str(repo), "add", "."], check=True)
            subprocess.run(["git", "-C", str(repo), "commit", "-qm", "first"], check=True)
            head = subprocess.check_output(["git", "-C", str(repo), "rev-parse", "HEAD"], text=True).strip()
            output = root / "pages"
            output.mkdir()
            (output / f"{head}.html").write_text("old layout")
            (output / f"{head}.json").write_text('{"v": 1}')
            (output / "page-7.html").write_text("stale")

            vault_history.render(repo / ".git", repo, output)

            self.assertIn("hello", (output / f"{head}.html").read_text())
            self.assertFalse((output / "page-7.html").exists())

    def test_paths_long_lines_and_odd_subjects_render(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo = root / "vault"
            repo.mkdir()
            git = ["git", "-C", str(repo)]
            subprocess.run(["git", "init", "-q", str(repo)], check=True)
            subprocess.run([*git, "config", "user.name", "Test"], check=True)
            subprocess.run([*git, "config", "user.email", "test@example.org"], check=True)
            (repo / "Meeting notes.md").write_text("hello\n")
            (repo / "img.png").write_bytes(b"\x89PNG\0one")
            (repo / "plugin.js").write_text("x=1;" * 2000 + "\n")
            subprocess.run([*git, "add", "."], check=True)
            subprocess.run([*git, "commit", "-qm", "first"], check=True)
            (repo / "Meeting notes.md").write_text("hello there\n")
            (repo / "img.png").write_bytes(b"\x89PNG\0two")
            (repo / "plugin.js").write_text("x=1;" * 1999 + "x=2;\n")
            subprocess.run([*git, "commit", "-qam", "Save\u2028evil"], check=True)
            head = subprocess.check_output([*git, "rev-parse", "HEAD"], text=True).strip()

            output = root / "pages"
            vault_history.render(repo / ".git", repo, output)

            meta = json.loads((output / f"{head}.json").read_text())
            self.assertEqual(sorted(meta["files"]), ["Meeting notes.md", "img.png", "plugin.js"])
            page = (output / f"{head}.html").read_text()
            self.assertIn("Binary file changed", page)
            self.assertNotIn("l mod", page)  # too long to word-diff: plain -/+ rows
            self.assertIn("Save\u2028evil", (output / "index.html").read_text())

    def test_server_requires_auth_for_index_and_commit_pages(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "index.html").write_text("history")
            (root / "commit.html").write_text("diff")
            server = vault_history.make_server("127.0.0.1", 0, root, "facc", "secret")
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                for path in ("/", "/commit.html"):
                    with self.assertRaises(HTTPError) as error:
                        urlopen(f"http://127.0.0.1:{server.server_port}{path}")
                    self.assertEqual(error.exception.code, 401)
                    error.exception.close()
                    wrong = base64.b64encode(b"facc:wrong").decode("ascii")
                    wrong_request = Request(
                        f"http://127.0.0.1:{server.server_port}{path}",
                        headers={"Authorization": f"Basic {wrong}"},
                    )
                    with self.assertRaises(HTTPError) as error:
                        urlopen(wrong_request)
                    self.assertEqual(error.exception.code, 401)
                    error.exception.close()
                    token = base64.b64encode(b"facc:secret").decode("ascii")
                    request = Request(
                        f"http://127.0.0.1:{server.server_port}{path}",
                        headers={"Authorization": f"Basic {token}"},
                    )
                    with urlopen(request) as response:
                        self.assertEqual(response.status, 200)
            finally:
                server.shutdown()
                server.server_close()
                thread.join()


if __name__ == "__main__":
    unittest.main()
