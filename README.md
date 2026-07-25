# Kırbac

A native macOS menu bar app. When Claude Code (or any CLI) is going too slow, whip it into shape.

Click the tray icon, crack the whip — it sends Ctrl+C and types a random “go faster” line into the focused app.

## Build + run

```bash
./scripts/build.sh
open Kirbac.app
```

Universal binary (Apple Silicon + Intel).

## Controls

- Left-click tray icon → spawn whip
- Flick the mouse → crack (Ctrl+C + random phrase)
- Click → drop whip
- Right-click → Quit

On first run, grant **Accessibility** under System Settings → Privacy & Security.
