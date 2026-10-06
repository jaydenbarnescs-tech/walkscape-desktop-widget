# WalkScape Widget for macOS

Your [WalkScape](https://walkscape.app) steps and stats as a native widget on the macOS desktop.
Pick your character once, drag the widget onto the desktop, done.

- Total steps, today's steps, a 7-day chart, level, total XP, achievement points and your top skills
- Small, medium and large sizes
- Pixel-art background that matches where your character is standing (meadow, forest, coast, mountain, desert), or pick one yourself
- A **LIVE** badge when the game synced in the last 3 minutes, otherwise how long ago it last synced
- No password, no account linking, no tracking

> **Unofficial fan project.** Not affiliated with, endorsed by, or sponsored by WalkScape or its creators. No WalkScape assets are included; all artwork in this repo is original. See [NOTICE.md](NOTICE.md).

## Install

Requires macOS 14 or newer and the Xcode Command Line Tools (`xcode-select --install`). Full Xcode is not needed.

```bash
git clone https://github.com/jaydenbarnescs-tech/walkscape-desktop-widget.git
cd walkscape-desktop-widget
./install.sh
```

The setup app opens when it finishes:

1. Type your character name (or paste your walkstats.app link) and click your character.
2. Right-click the desktop, choose **Edit Widgets**, search **WalkScape**, and drag a size onto the desktop.

Uninstall with `./uninstall.sh`.

## "Sign in"

WalkScape character stats are public, so there is nothing to log in to and the app never sees a password. "Signing in" means choosing which character to show. Characters hidden from the leaderboard won't appear in name search; paste your walkstats.app profile link instead.

## How it works

- The widget reads `GET api.web.walkscape.app/portal/shared/characters/<id>` (public, unauthenticated) every ~5 minutes.
- Name search builds a local player list from the public leaderboard pages once a day (cached in `~/.config/walkscape-widget/`).
- The API only reports lifetime steps, so "today" and the 7-day chart come from a small log the widget keeps itself. They start at zero on first install and fill in as you walk.
- Your choice is stored in `~/.config/walkscape-widget/config.json`. The widget is sandboxed and can only read that folder and reach the network.

## Limits

- macOS decides how often widgets refresh (roughly every 5 minutes), so it is near real time, not live. The game itself uploads about once a minute while the phone app is open.
- The build is signed ad-hoc (no Apple developer account), so it only runs on the Mac that built it. macOS updates occasionally reset this; re-run `./install.sh`.
- The WalkScape API is unofficial and may change.

## Repo layout

| Path | What |
|---|---|
| `Shared/` | API client, settings, formatting (used by both the app and the widget) |
| `Widget/` | The WidgetKit extension |
| `App/` | The setup / character picker app |
| `Resources/` | Background images and icon |
| `art/` | Prompts used to generate the backgrounds |

## License

MIT for the code and the original background art (see [LICENSE](LICENSE)). That license does not cover the WalkScape name, logo or game content, which belong to their owners. See [NOTICE.md](NOTICE.md) for the fan-project notice and takedown policy.
