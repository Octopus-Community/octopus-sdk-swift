#!/usr/bin/env swift
//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

// Renders app-icon.svg (the A3 icon) into the sample's 1024 pt AppIcon, opaque, with CoreGraphics only: no image generator,
// no third-party tool. It reads just what app-icon.svg uses: one userSpaceOnUse linear gradient and `<path>`
// elements with absolute M/L/C/H/V/Z (and relative h/v) commands, a solid or gradient fill and an optional
// even-odd rule.
//
//     swift Sample/AppIcon/render-app-icon.swift
//
// Run from the repository root; it overwrites Sample/OctopusSample/Resources/Assets.xcassets/AppIcon.appiconset/
// AppIcon.png.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let svgPath = "Sample/AppIcon/app-icon.svg"
let outputPath = "Sample/OctopusSample/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
let size = 1024

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("render-app-icon: \(message)\n".utf8))
    exit(1)
}

guard let svg = try? String(contentsOfFile: svgPath, encoding: .utf8) else { fail("cannot read \(svgPath)") }

func matches(_ pattern: String, in text: String) -> [[String]] {
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
        fail("bad pattern \(pattern)")
    }
    let range = NSRange(text.startIndex..., in: text)
    return regex.matches(in: text, range: range).map { match in
        (0..<match.numberOfRanges).map { index in
            Range(match.range(at: index), in: text).map { String(text[$0]) } ?? ""
        }
    }
}

func attribute(_ name: String, of element: String) -> String? {
    matches("\\s\(name)=\"([^\"]*)\"", in: element).first?[1]
}

func color(_ hex: String) -> CGColor {
    let value = UInt32(hex.dropFirst(), radix: 16) ?? 0
    return CGColor(srgbRed: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
                   blue: CGFloat(value & 0xFF) / 255, alpha: 1)
}

/// Absolute M, L, C, H, V, Z and relative h, v: everything app-icon.svg uses, and nothing more.
func path(_ data: String) -> CGPath {
    let tokens = matches("[MLCHVZmlchvz]|-?[0-9]*\\.?[0-9]+(?:[eE][-+]?[0-9]+)?", in: data).map { $0[0] }
    let path = CGMutablePath()
    var index = 0
    var command = ""
    func number() -> CGFloat {
        guard index < tokens.count, let value = Double(tokens[index]) else { fail("bad path data near \(index)") }
        index += 1
        return CGFloat(value)
    }
    while index < tokens.count {
        if tokens[index].first?.isLetter == true {
            command = tokens[index]
            index += 1
        }
        switch command {
        case "M":
            path.move(to: CGPoint(x: number(), y: number()))
            command = "L"
        case "L": path.addLine(to: CGPoint(x: number(), y: number()))
        case "C":
            let control1 = CGPoint(x: number(), y: number())
            let control2 = CGPoint(x: number(), y: number())
            path.addCurve(to: CGPoint(x: number(), y: number()), control1: control1, control2: control2)
        case "H": path.addLine(to: CGPoint(x: number(), y: path.currentPoint.y))
        case "V": path.addLine(to: CGPoint(x: path.currentPoint.x, y: number()))
        case "h": path.addLine(to: CGPoint(x: path.currentPoint.x + number(), y: path.currentPoint.y))
        case "v": path.addLine(to: CGPoint(x: path.currentPoint.x, y: path.currentPoint.y + number()))
        case "Z", "z": path.closeSubpath()
        default: fail("unsupported path command \(command)")
        }
    }
    return path
}

guard let viewBox = attribute("viewBox", of: matches("<svg[^>]*>", in: svg).first?[0] ?? "")?
    .split(separator: " ").compactMap({ Double($0) }), viewBox.count == 4 else { fail("no viewBox") }

guard let gradient = matches("<linearGradient([^>]*)>(.*?)</linearGradient>", in: svg).first,
      let gradientId = attribute("id", of: gradient[1]) else { fail("no linearGradient") }
let stops = matches("<stop[^>]*/>", in: gradient[2]).map { $0[0] }
let gradientStart = CGPoint(x: Double(attribute("x1", of: gradient[1]) ?? "0") ?? 0,
                            y: Double(attribute("y1", of: gradient[1]) ?? "0") ?? 0)
let gradientEnd = CGPoint(x: Double(attribute("x2", of: gradient[1]) ?? "0") ?? 0,
                          y: Double(attribute("y2", of: gradient[1]) ?? "0") ?? 0)
guard let shading = CGGradient(
    colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
    colors: stops.map { color(attribute("stop-color", of: $0) ?? "#000000") } as CFArray,
    locations: stops.map { CGFloat(Double(attribute("offset", of: $0) ?? "0") ?? 0) }) else {
    fail("bad gradient")
}

guard let space = CGColorSpace(name: CGColorSpace.sRGB),
      let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                              space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fail("cannot create the bitmap")
}
// SVG user space, y down, onto the bitmap: flip, then fit the viewBox to the full square.
context.translateBy(x: 0, y: CGFloat(size))
context.scaleBy(x: CGFloat(size) / viewBox[2], y: -CGFloat(size) / viewBox[3])
context.translateBy(x: -viewBox[0], y: -viewBox[1])

for element in matches("<path\\s[^>]*/>", in: svg).map({ $0[0] }) {
    guard let data = attribute("d", of: element), let fill = attribute("fill", of: element) else { continue }
    let shape = path(data)
    let rule: CGPathFillRule = attribute("fill-rule", of: element) == "evenodd" ? .evenOdd : .winding
    if fill == "url(#\(gradientId))" {
        context.saveGState()
        context.addPath(shape)
        context.clip(using: rule)
        context.drawLinearGradient(shading, start: gradientStart, end: gradientEnd,
                                   options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        context.restoreGState()
    } else {
        context.setFillColor(color(fill))
        context.addPath(shape)
        context.fillPath(using: rule)
    }
}

guard let image = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: outputPath) as CFURL,
                                                        UTType.png.identifier as CFString, 1, nil) else {
    fail("cannot write \(outputPath)")
}
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fail("cannot write \(outputPath)") }
print("render-app-icon: wrote \(outputPath) (\(size)x\(size), opaque)")
