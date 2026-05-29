#!/usr/bin/env swift
import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resourcesDirectory = root.appendingPathComponent("Resources", isDirectory: true)
let iconsetDirectory = resourcesDirectory.appendingPathComponent("InputMemory.iconset", isDirectory: true)
let masterURL = resourcesDirectory.appendingPathComponent("InputMemory-1024.png")

try FileManager.default.createDirectory(at: iconsetDirectory, withIntermediateDirectories: true)

struct IconSize {
    let fileName: String
    let pixels: Int
}

let iconSizes = [
    IconSize(fileName: "icon_16x16.png", pixels: 16),
    IconSize(fileName: "icon_16x16@2x.png", pixels: 32),
    IconSize(fileName: "icon_32x32.png", pixels: 32),
    IconSize(fileName: "icon_32x32@2x.png", pixels: 64),
    IconSize(fileName: "icon_128x128.png", pixels: 128),
    IconSize(fileName: "icon_128x128@2x.png", pixels: 256),
    IconSize(fileName: "icon_256x256.png", pixels: 256),
    IconSize(fileName: "icon_256x256@2x.png", pixels: 512),
    IconSize(fileName: "icon_512x512.png", pixels: 512),
    IconSize(fileName: "icon_512x512@2x.png", pixels: 1024)
]

func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        calibratedRed: CGFloat((hex >> 16) & 0xff) / 255,
        green: CGFloat((hex >> 8) & 0xff) / 255,
        blue: CGFloat(hex & 0xff) / 255,
        alpha: alpha
    )
}

func roundedRect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, _ radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: NSRect(x: x, y: y, width: width, height: height), xRadius: radius, yRadius: radius)
}

func drawIcon(in context: CGContext, scale: CGFloat) {
    func s(_ value: CGFloat) -> CGFloat { value * scale }

    context.saveGState()
    context.scaleBy(x: scale, y: scale)

    let canvas = NSRect(x: 0, y: 0, width: 1024, height: 1024)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)

    let outer = roundedRect(64, 64, 896, 896, 210)
    NSGradient(colors: [
        color(0xEAF7F4),
        color(0xDDEBFF),
        color(0x5F7BFF)
    ])?.draw(in: outer, angle: 135)

    color(0xFFFFFF, alpha: 0.24).setStroke()
    outer.lineWidth = 10
    outer.stroke()

    let shadow = NSShadow()
    shadow.shadowColor = color(0x1D2B4F, alpha: 0.22)
    shadow.shadowOffset = NSSize(width: 0, height: -22)
    shadow.shadowBlurRadius = 36
    shadow.set()

    let card = roundedRect(220, 248, 584, 528, 88)
    color(0xFFFFFF, alpha: 0.92).setFill()
    card.fill()

    NSShadow().set()
    color(0x31506D, alpha: 0.10).setStroke()
    card.lineWidth = 4
    card.stroke()

    let accent = roundedRect(290, 316, 42, 392, 21)
    NSGradient(colors: [
        color(0x21D6A6),
        color(0x2D7DFF)
    ])?.draw(in: accent, angle: 90)

    let caretGlow = roundedRect(278, 300, 66, 424, 33)
    color(0x2DADFF, alpha: 0.13).setFill()
    caretGlow.fill()

    let lineColor = color(0x2A3A59, alpha: 0.72)
    let mutedLineColor = color(0x2A3A59, alpha: 0.32)
    for (index, y) in [628, 548, 468].enumerated() {
        let line = roundedRect(388, CGFloat(y), index == 1 ? 298 : 244, 34, 17)
        (index == 0 ? lineColor : mutedLineColor).setFill()
        line.fill()
    }

    let nodeCenters: [CGPoint] = [
        CGPoint(x: 388, y: 358),
        CGPoint(x: 486, y: 358),
        CGPoint(x: 584, y: 358),
        CGPoint(x: 682, y: 358)
    ]

    color(0xAFC0D4, alpha: 0.82).setStroke()
    let timeline = NSBezierPath()
    timeline.move(to: nodeCenters[0])
    timeline.line(to: nodeCenters[3])
    timeline.lineWidth = 10
    timeline.lineCapStyle = .round
    timeline.stroke()

    for (index, center) in nodeCenters.enumerated() {
        let dot = NSBezierPath(ovalIn: NSRect(x: center.x - 24, y: center.y - 24, width: 48, height: 48))
        (index == 3 ? color(0x21D6A6) : color(0xFFFFFF)).setFill()
        dot.fill()
        color(0x5E78FF, alpha: index == 3 ? 0.42 : 0.28).setStroke()
        dot.lineWidth = 6
        dot.stroke()
    }

    let shine = NSBezierPath()
    shine.move(to: CGPoint(x: 170, y: 820))
    shine.curve(to: CGPoint(x: 650, y: 920), controlPoint1: CGPoint(x: 300, y: 925), controlPoint2: CGPoint(x: 520, y: 955))
    shine.lineWidth = 38
    shine.lineCapStyle = .round
    color(0xFFFFFF, alpha: 0.22).setStroke()
    shine.stroke()

    color(0x10233E, alpha: 0.04).setFill()
    NSBezierPath(rect: canvas).fill()

    NSGraphicsContext.restoreGraphicsState()
    context.restoreGState()

    _ = s(1)
}

func writeIcon(pixels: Int, to url: URL) throws {
    guard let context = CGContext(
        data: nil,
        width: pixels,
        height: pixels,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw NSError(domain: "InputMemoryIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create bitmap context"])
    }

    context.setFillColor(NSColor.clear.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: pixels, height: pixels))
    drawIcon(in: context, scale: CGFloat(pixels) / 1024)

    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else {
        throw NSError(domain: "InputMemoryIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not create PNG"])
    }
    CGImageDestinationAddImage(destination, image, nil)
    if !CGImageDestinationFinalize(destination) {
        throw NSError(domain: "InputMemoryIcon", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not write PNG"])
    }
}

try writeIcon(pixels: 1024, to: masterURL)
for size in iconSizes {
    try writeIcon(pixels: size.pixels, to: iconsetDirectory.appendingPathComponent(size.fileName))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = [
    "-c", "icns",
    iconsetDirectory.path,
    "-o", resourcesDirectory.appendingPathComponent("InputMemory.icns").path
]
try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
    throw NSError(domain: "InputMemoryIcon", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "iconutil failed"])
}

print("Generated Resources/InputMemory.icns")
