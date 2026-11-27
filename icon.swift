// Renders the app icon: `swift icon.swift out.png` (1024×1024).
// Line-art head whose face is covered by a video camera.
import AppKit

let S: CGFloat = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext
func gray(_ w: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(gray: w, alpha: a) }

// White macOS tile (824pt in the 1024 grid) so the black line art reads in dark mode too.
let tile = CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), cornerWidth: 185, cornerHeight: 185, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: gray(0, 0.3))
ctx.addPath(tile); ctx.setFillColor(gray(1)); ctx.fillPath()
ctx.restoreGState()

// Draw in the reference sketch's coordinates (y down, head ≈ 615×750), mapped into the tile.
ctx.translateBy(x: 0, y: S); ctx.scaleBy(x: 1, y: -1)
let k: CGFloat = 0.92
ctx.translateBy(x: 512 - 385 * k, y: 512 - 420 * k)
ctx.scaleBy(x: k, y: k)
func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

ctx.setStrokeColor(gray(0))
ctx.setLineCap(.round); ctx.setLineJoin(.round)

// Hair / skull
let hair = CGMutablePath()
hair.move(to: P(112, 330))
hair.addQuadCurve(to: P(150, 190), control: P(92, 245))
hair.addQuadCurve(to: P(172, 128), control: P(128, 150))   // cowlick
hair.addCurve(to: P(662, 262), control1: P(330, 40), control2: P(645, 70))
hair.addQuadCurve(to: P(658, 330), control: P(672, 300))
// Hair band
hair.move(to: P(118, 322)); hair.addLine(to: P(652, 322))
// Face: left ear → jaw → chin → right jaw → right ear
hair.move(to: P(116, 340))
hair.addLine(to: P(112, 400))
hair.addCurve(to: P(135, 535), control1: P(62, 415), control2: P(72, 520))
hair.addCurve(to: P(385, 795), control1: P(165, 700), control2: P(275, 795))
hair.addCurve(to: P(635, 535), control1: P(495, 795), control2: P(605, 700))
hair.addCurve(to: P(658, 400), control1: P(698, 520), control2: P(708, 415))
hair.addLine(to: P(654, 340))
ctx.addPath(hair); ctx.setLineWidth(38); ctx.strokePath()

// Video camera covering the face (white fill hides the face lines behind it)
let cam = CGMutablePath()
cam.addPath(CGPath(roundedRect: CGRect(x: 223, y: 430, width: 230, height: 180), cornerWidth: 36, cornerHeight: 36, transform: nil))
cam.move(to: P(453, 495)); cam.addLine(to: P(548, 445)); cam.addLine(to: P(548, 595)); cam.addLine(to: P(453, 545)); cam.closeSubpath()
ctx.addPath(cam); ctx.setFillColor(gray(1)); ctx.fillPath()
ctx.addPath(cam); ctx.setLineWidth(30); ctx.strokePath()

try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
