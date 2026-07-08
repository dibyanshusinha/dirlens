# DirLens

A lightweight macOS image viewer in the spirit of the old Windows Photo Viewer: opens one image, lets you page through every other image in the same folder, zoom, rotate, and pull up a hideable thumbnail filmstrip.

**[dibyanshusinha.github.io/dirlens](https://dibyanshusinha.github.io/dirlens/)** — download page with install instructions.

## Download

Grab the latest `.zip` from the [download page](https://dibyanshusinha.github.io/dirlens/) or the [Releases page](https://github.com/dibyanshusinha/dirlens/releases), unzip it, and drag `DirLens.app` to `/Applications`.

DirLens is free and distributed unsigned (no Apple Developer account behind it), so **macOS Gatekeeper will block the first launch** with a "cannot be opened because Apple cannot check it for malicious software" message. To open it the first time:

- Right-click (or Control-click) `DirLens.app` → **Open** → **Open** again in the dialog, **or**
- Run `xattr -dr com.apple.quarantine /Applications/DirLens.app` in Terminal.

You only need to do this once. After that it opens normally.

## Features

- Opens any image and automatically finds every other image (jpg, png, gif, bmp, tiff, heic/heif, webp) in the same folder for browsing.
- Next / Previous navigation via toolbar arrows or the `←` / `→` keys.
- Zoom in/out (toolbar, `⌘+` / `⌘-`), pinch-to-zoom trackpad gesture, pan when zoomed in, double-click to reset.
- Rotate left/right (toolbar, `⌘[` / `⌘]`).
- Hidden bottom drawer with thumbnails of every image in the folder — toggle with the toolbar button or `Space`. Click a thumbnail to jump straight to it.
- Drag-and-drop an image onto the window to open it.
- Delete the current image (toolbar or `⌘⌫`) — moves it to the Trash after confirmation, it's not permanently deleted.

## Run it during development

```bash
swift run
# or open a specific image directly:
swift run DirLens /path/to/photo.jpg
```

## Build a real .app you can double-click / install

```bash
./build_app.sh
open "dist/DirLens.app"
```

To install it:

```bash
cp -R "dist/DirLens.app" /Applications/
```

## Make it your default image viewer

1. In Finder, right-click any image → **Get Info**.
2. Under **Open with**, choose **DirLens**.
3. Click **Change All...** to make it the default for that file type.

## Keyboard shortcuts

| Action | Shortcut |
| --- | --- |
| Open image | `⌘O` |
| Previous / Next image | `←` / `→` |
| Zoom in / out | `⌘+` / `⌘-` |
| Reset zoom | `⌘0` |
| Rotate left / right | `⌘[` / `⌘]` |
| Toggle thumbnail drawer | `Space` |
| Reset zoom (double-click image) | double-click |
| Move image to Trash | `⌘⌫` |

## Project layout

```
Package.swift
Sources/DirLens/
  DirLensApp.swift          – app entry point, launch-arg & "Open With" handling
  ContentView.swift          – toolbar + layout
  ImageCanvasView.swift      – zoom/pan/rotate image display
  ThumbnailDrawerView.swift  – bottom thumbnail filmstrip
  AppState.swift              – navigation, zoom, rotation state
  FileScanner.swift           – finds sibling images in a folder
  ThumbnailCache.swift        – fast thumbnail generation via ImageIO
Resources/Info.plist          – app bundle metadata, registers as an image viewer
build_app.sh                   – packages a release build into DirLens.app
```

## License

[MIT](LICENSE)
