#!/usr/bin/env swift
// Renders Resources/AppIcon.icns without any external assets.
import AppKit
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let iconset = root.appendingPathComponent("build/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

/// Draws straight into a bitmap rep — no nested `lockFocus`, which fails at small sizes.
func render(pixels: Int) -> Data? {
    guard
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ),
        let context = NSGraphicsContext(bitmapImageRep: rep)
    else { return nil }

    let size = CGFloat(pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context

    // Rounded-rect background with the app gradient.
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let squircle = NSBezierPath(roundedRect: rect, xRadius: size * 0.2237, yRadius: size * 0.2237)
    squircle.addClip()
    NSGradient(
        colors: [
            NSColor(srgbRed: 0.20, green: 0.82, blue: 0.74, alpha: 1),
            NSColor(srgbRed: 0.11, green: 0.42, blue: 0.86, alpha: 1),
        ]
    )?.draw(in: rect, angle: -60)

    // A stylised broom: handle + fanned bristles, drawn in white.
    NSColor.white.withAlphaComponent(0.96).setStroke()
    NSColor.white.withAlphaComponent(0.96).setFill()

    let handle = NSBezierPath()
    handle.lineWidth = size * 0.075
    handle.lineCapStyle = .round
    handle.move(to: NSPoint(x: size * 0.66, y: size * 0.78))
    handle.line(to: NSPoint(x: size * 0.46, y: size * 0.46))
    handle.stroke()

    let head = NSBezierPath()
    head.move(to: NSPoint(x: size * 0.545, y: size * 0.545))
    head.line(to: NSPoint(x: size * 0.30, y: size * 0.40))
    head.line(to: NSPoint(x: size * 0.22, y: size * 0.20))
    head.line(to: NSPoint(x: size * 0.50, y: size * 0.24))
    head.close()
    head.fill()

    // Sparkle in the upper-left corner.
    let sparkle = NSBezierPath()
    let cx = size * 0.29, cy = size * 0.72, r = size * 0.115
    sparkle.move(to: NSPoint(x: cx, y: cy + r))
    sparkle.curve(to: NSPoint(x: cx + r, y: cy), controlPoint1: NSPoint(x: cx, y: cy + r * 0.25), controlPoint2: NSPoint(x: cx + r * 0.25, y: cy))
    sparkle.curve(to: NSPoint(x: cx, y: cy - r), controlPoint1: NSPoint(x: cx + r * 0.25, y: cy), controlPoint2: NSPoint(x: cx, y: cy - r * 0.25))
    sparkle.curve(to: NSPoint(x: cx - r, y: cy), controlPoint1: NSPoint(x: cx, y: cy - r * 0.25), controlPoint2: NSPoint(x: cx - r * 0.25, y: cy))
    sparkle.curve(to: NSPoint(x: cx, y: cy + r), controlPoint1: NSPoint(x: cx - r * 0.25, y: cy), controlPoint2: NSPoint(x: cx, y: cy + r * 0.25))
    sparkle.fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

let variants: [(Int, Int)] = [
    (16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2),
]
for (points, scale) in variants {
    guard let data = render(pixels: points * scale) else {
        print("✗ failed at \(points)x\(points)@\(scale)x")
        continue
    }
    let name = "icon_\(points)x\(points)\(scale == 1 ? "" : "@2x").png"
    try data.write(to: iconset.appendingPathComponent(name))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try process.run()
process.waitUntilExit()
print(process.terminationStatus == 0 ? "✓ Resources/AppIcon.icns" : "✗ iconutil failed")
