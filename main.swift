import AppKit
import AVFoundation

enum Shape: String, CaseIterable {
    case circle = "Circle", rounded = "Rounded", square = "Square", hexagon = "Hexagon", wide = "Wide 16:9"

    func path(in r: CGRect) -> CGPath {
        switch self {
        case .circle: return CGPath(ellipseIn: r, transform: nil)
        case .square: return CGPath(rect: r, transform: nil)
        case .rounded: return CGPath(roundedRect: r, cornerWidth: r.width * 0.2, cornerHeight: r.height * 0.2, transform: nil)
        case .wide: return CGPath(roundedRect: r, cornerWidth: r.height * 0.12, cornerHeight: r.height * 0.12, transform: nil)
        case .hexagon:
            let p = CGMutablePath(), rad = min(r.width, r.height) / 2
            for i in 0..<6 {
                let a = CGFloat.pi / 2 + CGFloat(i) * .pi / 3
                let pt = CGPoint(x: r.midX + rad * cos(a), y: r.midY + rad * sin(a))
                i == 0 ? p.move(to: pt) : p.addLine(to: pt)
            }
            p.closeSubpath()
            return p
        }
    }
}

final class Item: NSMenuItem {
    var handler: () -> Void = {}
    convenience init(_ title: String, on: Bool = false, _ h: @escaping () -> Void) {
        self.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self; handler = h; state = on ? .on : .off
    }
    @objc func fire() { handler() }
}

final class CamView: NSView {
    let preview: AVCaptureVideoPreviewLayer
    let border = CAShapeLayer(), shapeMask = CAShapeLayer()
    var shape = Shape.circle
    var onScroll: (CGFloat) -> Void = { _ in }
    var onResize: (_ size: CGFloat, _ done: Bool) -> Void = { _, _ in }
    var currentSize: () -> CGFloat = { 0 }

    init(session: AVCaptureSession) {
        preview = AVCaptureVideoPreviewLayer(session: session)
        super.init(frame: .zero)
        wantsLayer = true
        layer!.backgroundColor = NSColor.black.cgColor
        preview.videoGravity = .resizeAspectFill
        layer!.addSublayer(preview)
        border.fillColor = nil
        border.strokeColor = NSColor.white.cgColor
        border.lineWidth = 6 // half is clipped by the mask → 3pt visible
        layer!.addSublayer(border)
        layer!.mask = shapeMask
    }
    required init?(coder: NSCoder) { fatalError() }

    override var mouseDownCanMoveWindow: Bool { false }
    override func scrollWheel(with e: NSEvent) { onScroll(e.scrollingDeltaY) }

    // Outer ring of the shape = resize handle, inside = move.
    func onEdge(_ p: NSPoint) -> Bool {
        let r = min(bounds.width, bounds.height) / 2
        if shape == .wide || shape == .square || shape == .rounded {
            let inset = r * 0.25
            return !bounds.insetBy(dx: inset, dy: inset).contains(p)
        }
        return hypot(p.x - bounds.midX, p.y - bounds.midY) > r * 0.75
    }

    override func updateTrackingAreas() {
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }
    override func mouseMoved(with e: NSEvent) {
        guard onEdge(convert(e.locationInWindow, from: nil)) else { NSCursor.openHand.set(); return }
        if #available(macOS 15, *) { NSCursor.frameResize(position: .bottomRight, directions: .all).set() } else { NSCursor.crosshair.set() }
    }
    override func mouseExited(with e: NSEvent) { NSCursor.arrow.set() }

    override func mouseDown(with e: NSEvent) {
        guard let win = window else { return }
        guard onEdge(convert(e.locationInWindow, from: nil)) else { win.performDrag(with: e); return }
        // Scale around the window center by how far the mouse moves from it (screen coords, so no feedback loop).
        let c = NSPoint(x: win.frame.midX, y: win.frame.midY)
        let dist = { (p: NSPoint) in max(hypot(p.x - c.x, p.y - c.y), 1) }
        let start = dist(NSEvent.mouseLocation), startSize = currentSize()
        while let ev = win.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            let done = ev.type == .leftMouseUp
            onResize(startSize * dist(NSEvent.mouseLocation) / start, done)
            if done { break }
        }
    }
    override func layout() { super.layout(); layoutShape() }

    func layoutShape() {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        preview.frame = bounds; shapeMask.frame = bounds; border.frame = bounds
        let p = shape.path(in: bounds)
        shapeMask.path = p; border.path = p
        CATransaction.commit()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let session = AVCaptureSession()
    let d = UserDefaults.standard
    var panel: NSPanel!, cam: CamView!, status: NSStatusItem!

    var shape: Shape {
        get { Shape(rawValue: d.string(forKey: "shape") ?? "") ?? .circle }
        set { d.set(newValue.rawValue, forKey: "shape") }
    }
    var size: CGFloat {
        get { d.double(forKey: "size") > 0 ? d.double(forKey: "size") : 220 }
        set { d.set(min(max(newValue, 100), 900), forKey: "size") }
    }
    var mirror: Bool { get { d.object(forKey: "mirror") as? Bool ?? true } set { d.set(newValue, forKey: "mirror") } }
    var showBorder: Bool { get { d.object(forKey: "border") as? Bool ?? true } set { d.set(newValue, forKey: "border") } }
    var cameraID: String? { get { d.string(forKey: "camera") } set { d.set(newValue, forKey: "camera") } }

    var cameras: [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
                                         mediaType: .video, position: .unspecified).devices
    }

    func applicationDidFinishLaunching(_ n: Notification) {
        cam = CamView(session: session)
        cam.onScroll = { [unowned self] dy in size += dy * 2; apply() }
        cam.onResize = { [unowned self] s, done in size = s; apply(menu: done) }
        cam.currentSize = { [unowned self] in size }

        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: size, height: size),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        // The fullscreen trick: high level + join all spaces + aux to fullscreen, in an accessory (LSUIElement) app.
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.contentView = cam
        if !panel.setFrameUsingName("fcam"), let s = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: s.maxX - size - 40, y: s.minY + 40))
        }
        panel.setFrameAutosaveName("fcam")

        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "person.crop.circle", accessibilityDescription: "fcam")

        apply()
        panel.orderFrontRegardless()

        AVCaptureDevice.requestAccess(for: .video) { ok in
            DispatchQueue.main.async { ok ? self.useCamera(self.cameraID) : self.denied() }
        }
    }

    func useCamera(_ id: String?) {
        let all = cameras
        guard let dev = all.first(where: { $0.uniqueID == id }) ?? AVCaptureDevice.default(for: .video) ?? all.first,
              let input = try? AVCaptureDeviceInput(device: dev) else { rebuildMenu(); return }
        session.beginConfiguration()
        session.inputs.forEach(session.removeInput)
        if session.canAddInput(input) { session.addInput(input) }
        session.commitConfiguration()
        cameraID = dev.uniqueID
        if !session.isRunning { DispatchQueue.global().async { self.session.startRunning() } }
        apply()
    }

    func apply(menu: Bool = true) {
        let w = size, h = shape == .wide ? size * 9 / 16 : size
        var f = panel.frame
        f.origin.x += (f.width - w) / 2; f.origin.y += (f.height - h) / 2
        f.size = NSSize(width: w, height: h)
        panel.setFrame(f, display: true)
        cam.shape = shape
        cam.border.isHidden = !showBorder
        cam.layoutShape()
        if let c = cam.preview.connection, c.isVideoMirroringSupported {
            c.automaticallyAdjustsVideoMirroring = false
            c.isVideoMirrored = mirror
        }
        DispatchQueue.main.async { self.panel.invalidateShadow() }
        if menu { rebuildMenu() }
    }

    func rebuildMenu() {
        func sub(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
            let i = NSMenuItem(title: title, action: nil, keyEquivalent: ""), m = NSMenu()
            items.forEach(m.addItem); i.submenu = m; return i
        }
        let m = NSMenu()
        m.addItem(sub("Shape", Shape.allCases.map { s in Item(s.rawValue, on: s == shape) { [unowned self] in shape = s; apply() } }))
        m.addItem(sub("Size", [("Small", 150.0), ("Medium", 220), ("Large", 320), ("XL", 450)].map { name, v in
            Item(name, on: size == v) { [unowned self] in size = v; apply() } }))
        m.addItem(sub("Camera", cameras.map { c in Item(c.localizedName, on: c.uniqueID == cameraID) { [unowned self] in useCamera(c.uniqueID) } }))
        m.addItem(Item("Mirror", on: mirror) { [unowned self] in mirror.toggle(); apply() })
        m.addItem(Item("Border", on: showBorder) { [unowned self] in showBorder.toggle(); apply() })
        m.addItem(.separator())
        m.addItem(Item(panel.isVisible ? "Hide" : "Show") { [unowned self] in
            panel.isVisible ? panel.orderOut(nil) : panel.orderFrontRegardless(); rebuildMenu() })
        m.addItem(Item("Quit") { NSApp.terminate(nil) })
        status.menu = m
        cam.menu = m
    }

    func denied() {
        let a = NSAlert()
        a.messageText = "fcam needs camera access"
        a.informativeText = "Enable it in System Settings → Privacy & Security → Camera, then reopen fcam."
        a.addButton(withTitle: "Open Settings"); a.addButton(withTitle: "Quit")
        NSApp.activate(ignoringOtherApps: true)
        if a.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!)
        }
        NSApp.terminate(nil)
    }
}

if CommandLine.arguments.contains("--selftest") {
    let r = CGRect(x: 0, y: 0, width: 200, height: 200)
    for s in Shape.allCases {
        precondition(r.insetBy(dx: -1, dy: -1).contains(s.path(in: r).boundingBox), "\(s) path out of bounds")
    }
    let v = CamView(session: AVCaptureSession())
    v.frame = r
    precondition(v.onEdge(NSPoint(x: 195, y: 100)), "edge should resize")
    precondition(!v.onEdge(NSPoint(x: 100, y: 100)), "center should move")
    print("selftest ok")
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
