# fcam

Tiny floating facecam. 

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

1. Download `fcam.dmg` from [Releases](../../releases/latest) and open it
2. Drag `fcam.app` into the `Applications` folder
3. Run the `xattr` command above in Terminal
4. Open fcam and allow camera access

Requires macOS 14+, Apple Silicon or Intel.

## Build

```sh
./build.sh          # builds fcam.app
fcam.app/Contents/MacOS/fcam --selftest
```
