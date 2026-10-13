# Screenshots

The screenshots in the README come from the app running in the iOS Simulator with a demo photo library. They are regenerated with one script.

## The demo library

The demo library is made of original illustrations drawn by `scripts/demo-library/scenes.swift`: landscapes, a city at night, a coffee table and so on. No real photos are involved, so the screenshots are safe to publish.

`scripts/demo-library/library.swift` then turns those 16 scenes into a library that gives every part of the app something to show:
- photos spread over several years
- bursts of near-identical shots, for Similar Shots
- blurry, shaky, dark and overexposed shots
- a receipt and a concert ticket with a QR code
- a 75-second video and a short one

## Regenerating

From the repo root:

```bash
scripts/make-screenshots.sh
```

The script:
1. Renders the scenes and builds the library in a temporary folder.
2. Creates a fresh iPhone 17 Pro simulator on the newest release iOS runtime (set `RUNTIME` to choose another), in US English, with a clean status bar (9:41, full battery).
3. Adds the demo library to the simulator's Photos.
4. Runs `SnapSortUITests/ScreenshotTests`, which goes through onboarding, sorts a few photos, opens Smart groups and Similar Shots, and visits every tab.
5. Exports the captured images to `docs/screenshots/` at half resolution.
6. Relaunches the app in dark mode for one more shot of the deck.
7. Deletes the simulator.

It takes a few minutes, most of it spent waiting for the library scan to finish.

The UI test answers the iOS photo-access prompt itself. The scheme's test action must include the `SnapSortUITests` target.
