#!/usr/bin/env swift
import AppKit

// Vector artwork rendered at each native icon size. The globe keycap denotes
// keyboard languages; the opposing arrows denote switching. No font dependencies.
@MainActor
func drawIcon() {
    let tile = NSBezierPath(roundedRect: NSRect(x: 80, y: 80, width: 864, height: 864), xRadius: 194, yRadius: 194)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
    shadow.shadowBlurRadius = 28
    shadow.shadowOffset = NSSize(width: 0, height: -14)
    shadow.set()
    NSColor(calibratedRed: 0.15, green: 0.32, blue: 0.82, alpha: 1).setFill()
    tile.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(colors: [
        NSColor(calibratedRed: 0.12, green: 0.27, blue: 0.72, alpha: 1),
        NSColor(calibratedRed: 0.31, green: 0.53, blue: 0.96, alpha: 1)
    ])!.draw(in: tile, angle: 90)

    // A lower edge makes the white face read as a keyboard key.
    NSColor(calibratedRed: 0.63, green: 0.75, blue: 0.98, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 222, y: 216, width: 580, height: 590), xRadius: 102, yRadius: 102).fill()
    let face = NSBezierPath(roundedRect: NSRect(x: 222, y: 250, width: 580, height: 570), xRadius: 102, yRadius: 102)
    NSGradient(colors: [
        NSColor(calibratedRed: 0.90, green: 0.94, blue: 1, alpha: 1), .white
    ])!.draw(in: face, angle: 90)

    let ink = NSColor(calibratedRed: 0.17, green: 0.36, blue: 0.79, alpha: 1)
    ink.setStroke()
    let globe = NSBezierPath()
    globe.appendOval(in: NSRect(x: 362, y: 444, width: 300, height: 300))
    globe.appendOval(in: NSRect(x: 440, y: 444, width: 144, height: 300))
    globe.move(to: NSPoint(x: 362, y: 594))
    globe.line(to: NSPoint(x: 662, y: 594))
    globe.lineWidth = 23
    globe.stroke()

    func arrow(from start: NSPoint, to end: NSPoint) {
        let direction: CGFloat = end.x > start.x ? 1 : -1
        let path = NSBezierPath()
        path.move(to: start)
        path.line(to: end)
        path.move(to: NSPoint(x: end.x - direction * 35, y: end.y + 30))
        path.line(to: end)
        path.line(to: NSPoint(x: end.x - direction * 35, y: end.y - 30))
        path.lineWidth = 23
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.stroke()
    }
    arrow(from: NSPoint(x: 388, y: 382), to: NSPoint(x: 636, y: 382))
    arrow(from: NSPoint(x: 636, y: 316), to: NSPoint(x: 388, y: 316))
}

guard CommandLine.arguments.count == 2 else {
    fatalError("Usage: swift -swift-version 6 scripts/generate-icon.swift OUTPUT_DIRECTORY")
}
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let iconset = output.appendingPathComponent("AppIcon.iconset", isDirectory: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        let context = NSGraphicsContext(bitmapImageRep: bitmap)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        let transform = NSAffineTransform()
        transform.scale(by: CGFloat(pixels) / 1024)
        transform.concat()
        drawIcon()
        NSGraphicsContext.restoreGraphicsState()
        let data = bitmap.representation(using: .png, properties: [:])!
        let suffix = scale == 2 ? "@2x" : ""
        try data.write(to: iconset.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
        if pixels == 1024 { try data.write(to: output.appendingPathComponent("AppIcon.png")) }
    }
}
