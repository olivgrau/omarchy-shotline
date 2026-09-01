#!/usr/bin/env python
"""Tests for the renderer: session.json -> session.html + session.md."""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
RENDERER = os.path.join(ROOT, "bin", "shotline-render")

sys.path.insert(0, os.path.join(ROOT, "bin"))
loader = __import__("importlib.machinery", fromlist=["SourceFileLoader"])
render = loader.SourceFileLoader("render", RENDERER).load_module()


def session(shots, title="Login-Flow", created="2026-08-28T19:52:11+02:00"):
    return {
        "schema": 1,
        "id": "2026-08-28_19-52-11",
        "title": title,
        "created": created,
        "shots": shots,
    }


def shot(**kwargs):
    base = {
        "index": 1,
        "file": "01-login.png",
        "comment": "The login screen",
        "geometry": "100,200 812x460",
        "width": 812,
        "height": 460,
        "taken": "2026-08-28T19:52:20+02:00",
        "app": "firefox",
        "window": "Login",
    }
    base.update(kwargs)
    return base


class RenderCase(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp(prefix="shot-render-")
        self.addCleanup(shutil.rmtree, self.dir, True)

    def write(self, data):
        with open(os.path.join(self.dir, "session.json"), "w", encoding="utf-8") as handle:
            json.dump(data, handle)

    def render(self, data):
        self.write(data)
        loaded = render.load_session(self.dir)
        render.render_html(loaded, self.dir)
        render.render_markdown(loaded, self.dir)
        return self.read("session.html"), self.read("session.md")

    def read(self, name):
        with open(os.path.join(self.dir, name), encoding="utf-8") as handle:
            return handle.read()


class TestMarkdown(RenderCase):
    def test_shots_keep_their_order(self):
        _, md = self.render(session([
            shot(index=1, file="01-one.png", comment="First step"),
            shot(index=2, file="02-two.png", comment="Second step"),
            shot(index=3, file="03-three.png", comment="Third step"),
        ]))
        self.assertLess(md.index("First step"), md.index("Second step"))
        self.assertLess(md.index("Second step"), md.index("Third step"))
        self.assertIn("## 1. First step", md)
        self.assertIn("## 3. Third step", md)

    def test_image_paths_stay_relative(self):
        _, md = self.render(session([shot(file="01-login.png")]))
        self.assertIn("![Step 1](01-login.png)", md)
        self.assertNotIn(self.dir, md)

    def test_comment_becomes_a_quote_block(self):
        _, md = self.render(session([shot(comment="Line one\nLine two")]))
        self.assertIn("> Line one", md)
        self.assertIn("> Line two", md)

    def test_metadata_is_listed(self):
        _, md = self.render(session([shot(width=800, height=600, app="firefox", window="Login")]))
        self.assertIn("800x600 px", md)
        self.assertIn('firefox: "Login"', md)

    def test_hidpi_shows_both_sizes(self):
        _, md = self.render(session([shot(width=600, height=340,
                                          pixelWidth=960, pixelHeight=544)]))
        self.assertIn("600x340 px (image: 960x544 px)", md)

    def test_matching_sizes_are_shown_once(self):
        _, md = self.render(session([shot(width=800, height=600,
                                          pixelWidth=800, pixelHeight=600)]))
        self.assertIn("800x600 px", md)
        self.assertNotIn("image:", md)

    def test_missing_pixel_size_falls_back(self):
        _, md = self.render(session([shot(width=800, height=600,
                                          pixelWidth=0, pixelHeight=0)]))
        self.assertIn("800x600 px", md)
        self.assertNotIn("image:", md)

    def test_annotated_shot_is_flagged(self):
        html, md = self.render(session([shot(annotated=True)]))
        self.assertIn("Annotated: the highlights", md)
        self.assertIn("annotated", html)

    def test_plain_shot_has_no_flag(self):
        html, md = self.render(session([shot()]))
        self.assertNotIn("Annotated", md)
        self.assertNotIn(">annotated<", html)

    def test_missing_comment_is_stated(self):
        _, md = self.render(session([shot(comment="")]))
        self.assertIn("Comment: none", md)
        self.assertIn("## 1. Step 1", md)

    def test_empty_session_renders(self):
        _, md = self.render(session([]))
        self.assertIn("no screenshots", md)

    def test_singular_and_plural(self):
        _, md = self.render(session([shot()]))
        self.assertIn("1 commented screenshot", md)
        _, md = self.render(session([shot(), shot(index=2, file="02.png")]))
        self.assertIn("2 commented screenshots", md)


class TestHtml(RenderCase):
    def test_starts_light_and_can_toggle(self):
        html, _ = self.render(session([shot()]))
        self.assertNotIn('<html lang="de" data-theme="dark"', html)
        self.assertIn("toggleTheme()", html)
        self.assertIn("localStorage", html)
        self.assertIn('html[data-theme="dark"]', html)

    def test_is_self_contained(self):
        html, _ = self.render(session([shot()]))
        for pattern in ("http://", "https://", "cdn."):
            self.assertNotIn(pattern, html)

    def test_comment_is_escaped(self):
        html, _ = self.render(session([shot(comment='<script>alert("x")</script> & more')]))
        self.assertNotIn("<script>alert", html)
        self.assertIn("&lt;script&gt;", html)
        self.assertIn("&amp; more", html)

    def test_window_title_with_quotes_is_escaped(self):
        html, _ = self.render(session([shot(window='He said "hello"', app="firefox")]))
        self.assertIn("&quot;hello&quot;", html)

    def test_umlauts_survive(self):
        html, md = self.render(session([shot(comment="Größe der Auswahl prüfen")]))
        self.assertIn("Größe der Auswahl prüfen", html)
        self.assertIn("Größe der Auswahl prüfen", md)

    def test_image_tag_uses_relative_path(self):
        html, _ = self.render(session([shot(file="01-login.png")]))
        self.assertIn('src="01-login.png"', html)

    def test_every_shot_gets_a_section(self):
        html, _ = self.render(session([shot(), shot(index=2, file="02.png", comment="Two")]))
        self.assertEqual(html.count('<section class="shot">'), 2)


class TestHelpers(RenderCase):
    def test_long_comment_is_shortened_for_the_heading(self):
        label = render.shot_label({"comment": "x" * 200}, 1)
        self.assertLessEqual(len(label), 70)
        self.assertTrue(label.endswith("..."))

    def test_multiline_comment_uses_first_line_as_heading(self):
        label = render.shot_label({"comment": "Short form\nDetails follow"}, 1)
        self.assertEqual(label, "Short form")

    def test_unknown_schema_is_rejected(self):
        self.write({"schema": 99, "shots": []})
        with self.assertRaises(ValueError):
            render.load_session(self.dir)

    def test_broken_timestamp_survives(self):
        self.assertEqual(render.fmt_time("not-a-date"), "not-a-date")
        self.assertEqual(render.fmt_time(""), "")

    def test_time_is_readable(self):
        self.assertEqual(render.fmt_time("2026-08-28T19:52:11+02:00"), "28 August 2026 at 19:52")


class TestCli(RenderCase):
    def test_cli_writes_both_files(self):
        self.write(session([shot()]))
        result = subprocess.run([sys.executable, RENDERER, self.dir],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(os.path.exists(os.path.join(self.dir, "session.html")))
        self.assertTrue(os.path.exists(os.path.join(self.dir, "session.md")))

    def test_cli_rejects_missing_directory(self):
        result = subprocess.run([sys.executable, RENDERER, os.path.join(self.dir, "weg")],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
