import AppKit
let root = URL(fileURLWithPath: CommandLine.arguments[1])
let set = root.appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let transform = NSAffineTransform(); transform.scale(by: CGFloat(pixels) / 1024); transform.concat()
        let base = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 190, yRadius: 190)
        NSGradient(starting: NSColor(srgbRed: 0.22, green: 0.46, blue: 0.40, alpha: 1),
                   ending: NSColor(srgbRed: 0.10, green: 0.29, blue: 0.27, alpha: 1))!.draw(in: base, angle: -90)
        NSColor(srgbRed: 0.96, green: 0.94, blue: 0.87, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 250, y: 220, width: 520, height: 590), xRadius: 35, yRadius: 35).fill()
        NSColor(srgbRed: 0.82, green: 0.79, blue: 0.68, alpha: 1).setFill()
        NSBezierPath(rect: NSRect(x: 292, y: 220, width: 12, height: 590)).fill()
        NSColor(srgbRed: 0.78, green: 0.37, blue: 0.24, alpha: 1).setFill()
        let ribbon = NSBezierPath(); ribbon.move(to: NSPoint(x: 597, y: 810)); ribbon.line(to: NSPoint(x: 687, y: 810)); ribbon.line(to: NSPoint(x: 687, y: 575)); ribbon.line(to: NSPoint(x: 642, y: 615)); ribbon.line(to: NSPoint(x: 597, y: 575)); ribbon.close(); ribbon.fill()
        NSColor(srgbRed: 0.22, green: 0.46, blue: 0.40, alpha: 0.5).setFill()
        for y in [420, 485] { NSBezierPath(roundedRect: NSRect(x: 370, y: y, width: 200, height: 18), xRadius: 9, yRadius: 9).fill() }
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: set.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
