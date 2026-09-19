#!/usr/bin/env swift
// Generates a 1024x1024 Swiper app icon into the asset catalog.
// Run with: swift Scripts/generate_app_icon.swift   (from the repo root)
import AppKit

let side = 1024
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: side,
    pixelsHigh: side,
    bitsPerSample: 8,
    samplesPerPixel: 3,
    hasAlpha: false,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    FileHandle.standardError.write(Data("Failed to allocate bitmap\n".utf8))
    exit(1)
}
rep.size = NSSize(width: side, height: side)

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

NSColor(calibratedWhite: 0.06, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: side, height: side)).fill()

// A soft frame around the icon's content, suggesting a photo.
let frame = NSBezierPath(
    roundedRect: NSRect(x: 96, y: 200, width: 832, height: 624),
    xRadius: 72,
    yRadius: 72
)
frame.lineWidth = 34
NSColor(calibratedWhite: 0.28, alpha: 1).setStroke()
frame.stroke()

// A bold keep/accept check mark.
let check = NSBezierPath()
check.move(to: NSPoint(x: 300, y: 500))
check.line(to: NSPoint(x: 452, y: 348))
check.line(to: NSPoint(x: 740, y: 660))
check.lineWidth = 74
check.lineCapStyle = .round
check.lineJoinStyle = .round
NSColor.white.setStroke()
check.stroke()

NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:])
else {
    FileHandle.standardError.write(Data("Failed to render icon\n".utf8))
    exit(1)
}

let output = URL(fileURLWithPath: "Swiper/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")
try data.write(to: output)
print("Wrote \(output.path)")
