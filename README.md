# Frametop Hand Recorder

Record your hands with a Steam Frame to help Frametop's hand tracking, without installing [Frametop](https://github.com/Frametop/frametop). If you already run Frametop, stable or experimental, this works next to it as its own app.

The recorder runs in SteamVR's dashboard. You pick a **bounty**: a short round, about 4 minutes, of what the hand tracker needs most right now. Windows appear in front of you in the headset and you tap, pinch and grab them as you would real ones (index taps, middle-finger taps, pinches, three-finger card grabs), while the headset's tracking cameras record your hands. Afterwards you watch what was recorded, delete anything you don't want to share, export it, and upload it as a pull request from your own Hugging Face account to the public hand dataset, [DeeJanuz/frametop-hands](https://huggingface.co/datasets/DeeJanuz/frametop-hands), where it's used to train Frametop's hand tracking. Nothing leaves the headset until you press Upload.

**With Frametop installed** there's also a **testing session**: up to 3 minutes of using Frametop as you always do, while the cameras record your hands and what Frametop's hand tracking made of them. When the tracking gets something wrong, press the headset button: that marks the moment. New versions of the hand tracking are then tested on your recording, at those moments, before they ship. Testing sessions are never used for training and aren't published: they go to a separate, gated test dataset ([DeeJanuz/frametop-hands-test](https://huggingface.co/datasets/DeeJanuz/frametop-hands-test)), **encrypted on your headset** so that only the maintainer can open them.

While you record, the dashboard stays closed. Use the button on the right side of the headset: press it to start each step, press it twice to record a step again, and hold it to stop. In a testing session, a press marks a moment and a hold finishes.

**Status: testing.** The releases are test builds (the newest is on the [releases page](https://github.com/Frametop/frametop-hand-recorder/releases)). Before your first bounty the recorder shows the hand dataset's consent, and before your first testing session its own short testing consent. The maintainer checks every upload before it's merged.

Please report what works and what doesn't in this repo's [issues](https://github.com/Frametop/frametop-hand-recorder/issues) or the [Frametop Discord](https://discord.gg/W3X9f7z3Bc).

## Install

You need a Steam Frame with SteamOS and SteamVR, about 1.2 GB free for the install, and about 30 GB for each round of recording and its export (you can delete both once it's uploaded).

1. In the headset, open the dashboard, then **Launch a program** → **Konsole**.
2. Run:
   ```
   curl -fsSL https://raw.githubusercontent.com/Frametop/frametop-hand-recorder/main/get-hand-recorder.sh | bash
   ```
3. It asks for your password once. If you've never set one, run `passwd` first, then the command again.
4. Open the dashboard, then **Launch a program** → **Frametop Hand Recorder**.

It installs the newest release, test builds included. To update, run it again. To install one particular release, use the command in that release's notes on the [releases page](https://github.com/Frametop/frametop-hand-recorder/releases).

### What the installer changes

- It installs into `~/.local/share/frametop-hand-recorder`: the release in `versions/`, with `current` pointing at the one in use, and a Python environment in `venv/` with PySide6, huggingface_hub and cryptography from PyPI, pinned with hashes in `requirements.txt`.
- It gives the camera broker `ft-camd` three file capabilities with `sudo setcap`: `cap_sys_ptrace`, `cap_perfmon` and `cap_dac_read_search`. ft-camd copies the camera images from SteamVR's camera service, read-only, and drops the capabilities once it has set up. This is the only step that needs your password.
- It adds the menu entry `~/.local/share/applications/frametop-hand-recorder.desktop`.
- Recordings go to `~/.local/share/frametop/hands/contrib`, the same folder Frametop's own recorder uses. Your Hugging Face login, once you make one, goes to `~/.cache/huggingface/token`.

### Uninstall

```
~/.local/share/frametop-hand-recorder/current/get-hand-recorder.sh --uninstall
```

This runs the install's own copy of the installer. It removes the install, its Python environment and the menu entry. Your recordings and your Hugging Face login stay. The command says where they are, so you can delete them too.

## How it fits together

The recorder is Frametop's: the session runner, the review and export code, the camera broker `ft-camd`, the tracker `ft-hands` the headset panel `ft-handpanel`, the bounty board and the testing session all live in [Frametop's `hands/`](https://github.com/Frametop/frametop/tree/main/hands) (see `hands/rec/DESIGN.md` there). This repo pins Frametop as the `frametop/` submodule and adds what the standalone recorder needs:

| Here | What it is |
|---|---|
| `app/main.qml` | The window, in Qt Quick Controls, sized for the dashboard and a laser pointer (Frametop's own window uses Kirigami, which can't load into PySide6's Qt) |
| `bin/frametop-hand-recorder` | The launcher: Frametop's backend `ft_handrec.py` with this window, from the venv |
| `scripts/build.sh` | Builds the binaries for the SteamOS host on Ubuntu 24.04 (glibc 2.39): ft-camd and ft-hands statically, ft-handpanel against SteamVR's `libopenvr_api` |
| `scripts/check-binaries.sh` | Checks they'll run on SteamOS: static, or only libraries and symbol versions SteamOS has |
| `scripts/package.sh` | The release tarball, in Frametop's layout plus `standalone.json`, `get-hand-recorder.sh` and `SHA256SUMS` |
| `get-hand-recorder.sh` | The installer |
| `.github/workflows/build.yml` | CI on Depot's aarch64 runners (the Frametop org's account): build, check, test, package; a `v*` tag makes a draft release |
| `spike/` | A test window for what works in the dashboard (below) |

`standalone.json` at the top of the release tells Frametop's code that it runs standalone: `session.py` then starts ft-hands directly rather than in Frametop's dev container, records the release's version in each session, and its repair hints point at the install command.

A change to how the recorder records, reviews or uploads goes into Frametop first. Then this repo moves its submodule to that commit:

```
git -C frametop fetch origin && git -C frametop checkout <commit>
git add frametop && git commit
```

## Development

On a Frame, in a checkout with its submodule (`git clone --recursive`):

```
python3 -m venv .venv
.venv/bin/pip install --require-hashes -r requirements.txt
frame-job --local -- scripts/build-in-container.sh             # the binaries, on Ubuntu 24.04 (podman)
frame-job --local -- scripts/build-in-container.sh --package   # and the release in dist/
```

Leave out `frame-job --local --` on a machine without frame-job.

- **The window in a dry run:** `bin/frametop-hand-recorder --dry-run --hub-dry-run --base /tmp/hr`. Sessions start no processes, and Upload makes no network calls.
- **Tests:** `QT_QPA_PLATFORM=offscreen .venv/bin/python -m unittest discover -s tests`, and `FT_HANDREC_QML=$PWD/app/main.qml .venv/bin/python frametop/hands/rec/tests/test_qml_backend.py`. The second checks every backend property and slot the window uses.
- **Installing a local build:** `./get-hand-recorder.sh --from dist/frametop-hand-recorder-*-aarch64.tar.gz`.
- **The dashboard spike:** `spike/install.sh` adds "Hand Recorder spike" and "Hand Recorder (dev, dry run)" to Launch a program, and `spike/install.sh --remove` takes them away. The spike logs what it sees to `~/.local/state/frametop-hand-recorder/spike.log`: clicks, scrolling, keyboard text, the browser, the clipboard, the headset panel with the dashboard closed, the headset button, and the sleep block.
- **Python pins:** edit `requirements.in`, then run `scripts/lock-requirements.sh` on the Frame.

### Releasing

1. Move the submodule to the Frametop commit to ship, and push.
2. Tag `vX.Y.Z` and push the tag. CI builds it and makes a draft release, a pre-release if the tag has a `-` (`v0.2.0-rc1`).
3. Install the draft's tarball on a Frame with `--from`, and record a bounty (and, with Frametop installed, a testing session).
4. Publish the release. The install command above then installs it: the repo's `get-hand-recorder.sh` asks GitHub for the newest published release, pre-releases included, and runs that release's own copy. `releases/latest/download/get-hand-recorder.sh` only works for a tag without a `-`, as GitHub never counts a pre-release as the latest.

## License

MIT, like Frametop. See [LICENSE](LICENSE). A release also contains third-party code: see [THIRD-PARTY.md](THIRD-PARTY.md). The recordings you contribute are covered by the consent text the recorder shows before your first session.
