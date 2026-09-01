# X post kit: Shotline

Everything needed for a post about Shotline on X. Ready to copy, nothing left
to build.

## Contents

| Path | What |
|------|------|
| `post-en.md` | Thread (6 posts) and single post, with alt text and posting notes |
| `scenario.md` | The fictional scenario and story the material came from |
| `screenshots/` | Eight images, ready to attach |
| `video/shotline.mp4` | 30 seconds, 1280×720, ~600 KB — the main medium |
| `video/shotline.gif` | The same as a GIF, 640 px, ~1.2 MB |
| `video/build.sh` | Rebuilds video and GIF from the screenshots |
| `series/` | The real Shotline series the material shows |
| `demo-app/pedalio.html` | The fictional app from the screenshots |

## The images

| File | Shows |
|------|-------|
| `01-app-with-bugs.png` | The dashboard with the contradictory filter |
| `02-comment-dialog.png` | The comment box over the app, with the captured size |
| `03-bar-widget.png` | Bar widget: camera with counter, pen next to it |
| `04-annotation.png` | Annotated date rows, brush tool |
| `05-session-html-light.png` | The result as HTML, light |
| `06-session-html-dark.png` | The same in dark |
| `07-session-md.png` | `session.md`, the way the agent reads it |
| `08-agent-prompt.png` | The prompt after `shotline finish` |

## How to post it

1. Open `post-en.md`, pick option A (thread) or B (single post).
2. Write the first post, attach `video/shotline.mp4`.
3. Copy the alt text from the table in that file into each image.
4. For a thread: send the replies back to back, not spread across the day.

Every text block is counted and stays under 280 characters. The count sits in
each heading.

## How this material was made

The screenshots are real: captured with Shotline itself, in a real session over
the mock in `demo-app/pedalio.html`. The mock exists so that no real customer
data and no private windows end up in the images.

Two things were added afterwards and belong on the record:

- The red annotations in `04-annotation.png` (and in the second image of the
  series) are drawn with ImageMagick, not painted by hand in the editor. The
  result matches what `tensaku` would have produced, but nobody painted it.
- In the series' `session.md` and `session.html` the Chromium window class was
  shortened: it held the full local file path of the mock, because the app ran
  as a `file://` page. A real web app would show only the window name there.

`video/build.sh` rebuilds video and GIF from the screenshots at any time.
