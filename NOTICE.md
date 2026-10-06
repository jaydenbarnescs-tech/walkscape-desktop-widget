# Credits and notice: unofficial fan project

## Credits

**WalkScape** is created and published by **Not a Cult Oy** (Finland). WalkScape, its name, logo, characters,
game world, items, locations, names and all related game content are © Not a Cult Oy. All rights reserved.
This project exists because of their game, and every number it shows comes from their service.

- Play and support the game: <https://walkscape.app>
- Official press kit and contact: <https://walkscape.app/presskit> · contact@walkscape.app
- Official community wiki: <https://wiki.walkscape.app>
- Community tools that inspired this one: [WalkStats](https://walkstats.app) and the other projects in the
  [Walkscape-Index](https://walkscape-index.github.io/)
- Background art was generated with OpenAI's image generation (via Codex) from original prompts (`art/gen.sh`).
  The widget is written in Swift with Apple's WidgetKit and SwiftUI.

**WalkScape Widget is an unofficial, non-commercial fan project.** It is not made, endorsed, sponsored or
approved by the creators or publishers of WalkScape.

- "WalkScape", its logo, characters, names, game content and artwork belong to their respective owners.
  They are used here only to refer to the game (nominative use) and remain the property of those owners.
- **No WalkScape assets are included in this repository.** No logos, sprites, map tiles or screenshots.
  The widget backgrounds in `Resources/` are original AI-generated pixel-art landscapes made for this project
  (see `art/gen.sh` for the prompts); they only share a general retro pixel-art genre look.
- The app uses WalkScape's public, unauthenticated web endpoints to read stats that players already share
  publicly. It does not ask for, store or transmit any WalkScape password or token, and it makes only a
  handful of lightweight requests (one per widget refresh, plus a once-a-day leaderboard read for name search).
  These endpoints are unofficial and the game's owners may change or restrict them at any time.
- This project is free and has no ads, tracking or paid features. It must stay that way.
- If the owners of WalkScape ask for changes or for this project to be taken down, it will be done promptly.
  Please open an issue or contact the repository owner.

The source code is licensed under the MIT License (see `LICENSE`). The MIT license covers the code and the
original backgrounds only. It grants no rights in the WalkScape name, logo or game content.
