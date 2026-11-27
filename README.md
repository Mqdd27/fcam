# fcam

Tiny floating facecam for macOS (~280 KB). Stays on top — even over fullscreen apps.

- Shapes: circle, rounded, square, hexagon, wide 16:9
- Drag the center to move, drag the edge (or scroll) to resize
- Preset sizes, camera picker (incl. iPhone Continuity Camera), mirror, border
- Lives in the menu bar; right-click the cam for the same menu

## Install

> [!IMPORTANT]
> fcam isn't notarized by Apple, so macOS will block it ("fcam is damaged" / "can't be opened") until you run this **once** after installing:
> ```sh
> xattr -dr com.apple.quarantine /Applications/fcam.app
> ```

1. Download `fcam.zip` from [Releases](../../releases/latest) and unzip
2. Move `fcam.app` to `/Applications`
3. Run the `xattr` command above in Terminal
4. Open fcam and allow camera access

Requires macOS 14+, Apple Silicon or Intel.

## Build

```sh
./build.sh          # builds fcam.app
fcam.app/Contents/MacOS/fcam --selftest
```

Release: push a tag like `v1.0.1` — CI builds and attaches `fcam.zip`.
