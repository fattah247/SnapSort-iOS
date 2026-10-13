// Renders 16 original illustrated scenes (landscapes, a city at night, a
// coffee table and so on) that stand in for photos in the demo library.
// They're drawn from scratch, so screenshots of them are safe to publish.
//
// Usage: swift scenes.swift <output folder>
import AppKit
import CoreImage
import ImageIO
import UniformTypeIdentifiers

let outDir = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

let W: CGFloat = 1500, H: CGFloat = 2000
let space = CGColorSpace(name: CGColorSpace.sRGB)!

struct RNG {
    var state: UInt64
    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((state >> 33) % 10_000) / 10_000
    }
    mutating func range(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * next() }
}

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

func vertical(_ c: CGContext, _ colors: [UInt32], _ rect: CGRect) {
    let g = CGGradient(colorsSpace: space, colors: colors.map { rgb($0) } as CFArray, locations: nil)!
    c.saveGState(); c.clip(to: rect)
    c.drawLinearGradient(g, start: CGPoint(x: 0, y: rect.maxY), end: CGPoint(x: 0, y: rect.minY), options: [])
    c.restoreGState()
}

func circle(_ c: CGContext, _ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ color: CGColor) {
    c.setFillColor(color); c.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
}

func glow(_ c: CGContext, _ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ hex: UInt32) {
    let g = CGGradient(colorsSpace: space, colors: [rgb(hex, 0.55), rgb(hex, 0)] as CFArray, locations: [0, 1])!
    c.drawRadialGradient(g, startCenter: CGPoint(x: x, y: y), startRadius: 0, endCenter: CGPoint(x: x, y: y), endRadius: r, options: [])
}

/// A jagged ridge from left to right, filled down to the bottom
func ridge(_ c: CGContext, base: CGFloat, height: CGFloat, roughness: Int, color: CGColor, rng: inout RNG, smooth: Bool = false) {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: 0, y: 0))
    path.addLine(to: CGPoint(x: 0, y: base + rng.range(0, height)))
    let step = W / CGFloat(roughness)
    var last = CGPoint(x: 0, y: base)
    for i in 1...roughness {
        let p = CGPoint(x: CGFloat(i) * step, y: base + rng.range(0, height))
        if smooth {
            path.addQuadCurve(to: p, control: CGPoint(x: (last.x + p.x) / 2, y: max(last.y, p.y) + height * 0.25))
        } else {
            path.addLine(to: p)
        }
        last = p
    }
    path.addLine(to: CGPoint(x: W, y: 0)); path.closeSubpath()
    c.setFillColor(color); c.addPath(path); c.fillPath()
}

func tree(_ c: CGContext, _ x: CGFloat, _ y: CGFloat, _ h: CGFloat, _ color: CGColor) {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: x - h * 0.22, y: y)); p.addLine(to: CGPoint(x: x, y: y + h)); p.addLine(to: CGPoint(x: x + h * 0.22, y: y)); p.closeSubpath()
    c.setFillColor(color); c.addPath(p); c.fillPath()
}

func stars(_ c: CGContext, _ count: Int, minY: CGFloat, rng: inout RNG) {
    for _ in 0..<count { circle(c, rng.range(0, W), rng.range(minY, H), rng.range(1.5, 4), rgb(0xFFFFFF, rng.range(0.4, 1))) }
}

typealias Scene = (CGContext, inout RNG) -> Void

let scenes: [(String, Scene)] = [
    ("sunset_peaks", { c, r in
        vertical(c, [0xFF9A62, 0xF2667A, 0x6C4A9E, 0x2B2F6B], CGRect(x: 0, y: 0, width: W, height: H))
        glow(c, 1000, 1050, 600, 0xFFD9A0); circle(c, 1000, 1050, 140, rgb(0xFFE6B8))
        ridge(c, base: 820, height: 380, roughness: 9, color: rgb(0x8A4E8C), rng: &r)
        ridge(c, base: 600, height: 300, roughness: 11, color: rgb(0x5B3576), rng: &r)
        ridge(c, base: 380, height: 220, roughness: 14, color: rgb(0x33204F), rng: &r)
    }),
    ("beach_day", { c, r in
        vertical(c, [0xBFE6FF, 0x7CC4F2], CGRect(x: 0, y: 900, width: W, height: H - 900))
        glow(c, 380, 1620, 420, 0xFFF4C2); circle(c, 380, 1620, 110, rgb(0xFFF6D6))
        vertical(c, [0x2E8FC9, 0x56B7E0], CGRect(x: 0, y: 620, width: W, height: 280))
        for i in 0..<6 { c.setStrokeColor(rgb(0xFFFFFF, 0.5)); c.setLineWidth(6); c.move(to: CGPoint(x: r.range(0, 900), y: 660 + CGFloat(i) * 40)); c.addLine(to: CGPoint(x: r.range(900, 1500), y: 660 + CGFloat(i) * 40)); c.strokePath() }
        vertical(c, [0xE9D3A8, 0xF4E4C1], CGRect(x: 0, y: 0, width: W, height: 640))
        for _ in 0..<5 { circle(c, r.range(100, 1400), r.range(150, 500), r.range(18, 34), rgb(0xFFFFFF, 0.6)) }
    }),
    ("misty_forest", { c, r in
        vertical(c, [0xDDE8DF, 0xA9C4B0], CGRect(x: 0, y: 0, width: W, height: H))
        for (layer, color) in [(0, 0x8FAE98), (1, 0x5F8A6E), (2, 0x355E45), (3, 0x1E3B2B)].enumerated() {
            let y = 1100 - CGFloat(layer) * 300
            for _ in 0..<(14 + layer * 4) { tree(c, r.range(-50, 1550), y + r.range(-60, 40), r.range(360, 560) + CGFloat(layer) * 120, rgb(UInt32(color.1))) }
        }
    }),
    ("city_night", { c, r in
        vertical(c, [0x0E1A3B, 0x23305E, 0x4B3F7A], CGRect(x: 0, y: 0, width: W, height: H))
        stars(c, 120, minY: 1100, rng: &r)
        circle(c, 1180, 1720, 90, rgb(0xF6F1DA)); glow(c, 1180, 1720, 260, 0xF6F1DA)
        var x: CGFloat = -20
        while x < W {
            let w = r.range(150, 260), h = r.range(500, 1250)
            c.setFillColor(rgb(0x141B33)); c.fill(CGRect(x: x, y: 0, width: w, height: h))
            var wy: CGFloat = 60
            while wy < h - 60 {
                var wx = x + 24
                while wx < x + w - 40 { if r.next() > 0.55 { c.setFillColor(rgb(0xFFD27A, r.range(0.6, 1))); c.fill(CGRect(x: wx, y: wy, width: 22, height: 30)) }; wx += 42 }
                wy += 56
            }
            x += w + r.range(6, 20)
        }
    }),
    ("desert_dunes", { c, r in
        vertical(c, [0xFFD8A8, 0xF7B57A, 0xEFA06A], CGRect(x: 0, y: 0, width: W, height: H))
        circle(c, 500, 1500, 120, rgb(0xFFF1D0)); glow(c, 500, 1500, 380, 0xFFE2B0)
        ridge(c, base: 820, height: 200, roughness: 4, color: rgb(0xE08A55), rng: &r, smooth: true)
        ridge(c, base: 560, height: 260, roughness: 3, color: rgb(0xC96F43), rng: &r, smooth: true)
        ridge(c, base: 260, height: 240, roughness: 3, color: rgb(0xA65634), rng: &r, smooth: true)
    }),
    ("alpine_lake", { c, r in
        vertical(c, [0xA8D4F0, 0xE8F4FB], CGRect(x: 0, y: 900, width: W, height: H - 900))
        var mirror = r
        ridge(c, base: 1150, height: 520, roughness: 8, color: rgb(0x6E8FA8), rng: &r)
        c.saveGState(); c.translateBy(x: 0, y: 1800); c.scaleBy(x: 1, y: -1)
        ridge(c, base: 1150, height: 520, roughness: 8, color: rgb(0x6E8FA8, 0.45), rng: &mirror)
        c.restoreGState()
        vertical(c, [0x3C7A93, 0x6FA9BF], CGRect(x: 0, y: 0, width: W, height: 640))
        c.setFillColor(rgb(0x2F5B3D)); c.fill(CGRect(x: 0, y: 610, width: W, height: 40))
        for _ in 0..<26 { tree(c, r.range(0, W), 640, r.range(120, 220), rgb(0x24452F)) }
    }),
    ("aurora", { c, r in
        vertical(c, [0x050B1F, 0x0D2240, 0x123A4A], CGRect(x: 0, y: 0, width: W, height: H))
        stars(c, 220, minY: 500, rng: &r)
        for (i, hex) in [0x46F2B0, 0x7BE0FF, 0xA77BFF].enumerated() {
            let p = CGMutablePath(); let y0 = 1350 + CGFloat(i) * 120
            p.move(to: CGPoint(x: -100, y: y0))
            p.addCurve(to: CGPoint(x: 1600, y: y0 + 200), control1: CGPoint(x: 500, y: y0 + 450), control2: CGPoint(x: 1000, y: y0 - 300))
            c.setStrokeColor(rgb(UInt32(hex), 0.35)); c.setLineWidth(160); c.setLineCap(.round); c.addPath(p); c.strokePath()
        }
        ridge(c, base: 300, height: 160, roughness: 12, color: rgb(0x07101C), rng: &r)
        for _ in 0..<30 { tree(c, r.range(0, W), 300, r.range(140, 260), rgb(0x040A12)) }
    }),
    ("wildflowers", { c, r in
        vertical(c, [0xCFEAFF, 0x9FD3F5], CGRect(x: 0, y: 1150, width: W, height: H - 1150))
        vertical(c, [0x3E8E4A, 0x7CC066], CGRect(x: 0, y: 0, width: W, height: 1160))
        for _ in 0..<260 {
            let y = r.range(0, 1100), size = 10 + (1100 - y) / 45
            let hex: UInt32 = [0xFF6F91, 0xFFC75F, 0xF9F871, 0xFFFFFF, 0xC34A36, 0xB39CD0][Int(r.range(0, 5.99))]
            circle(c, r.range(0, W), y, size, rgb(hex))
        }
    }),
    ("hot_air_balloons", { c, r in
        vertical(c, [0xFFE0C2, 0xBFE0F5, 0x8CC8EE], CGRect(x: 0, y: 0, width: W, height: H))
        ridge(c, base: 120, height: 180, roughness: 6, color: rgb(0x8AA77F), rng: &r, smooth: true)
        for (x, y, s, hex) in [(420.0, 1380.0, 1.0, 0xE85D75), (1080, 1600, 0.7, 0xF6B53F), (900, 900, 0.55, 0x4DA6A8), (300, 700, 0.4, 0x8E6BBF), (1250, 1050, 0.35, 0x3A8DDE)] as [(CGFloat, CGFloat, CGFloat, UInt32)] {
            circle(c, x, y, 190 * s, rgb(hex))
            c.setFillColor(rgb(0xFFFFFF, 0.25)); c.fillEllipse(in: CGRect(x: x - 60 * s, y: y - 190 * s, width: 120 * s, height: 380 * s))
            c.setFillColor(rgb(0x6B4A2E)); c.fill(CGRect(x: x - 30 * s, y: y - 300 * s, width: 60 * s, height: 50 * s))
        }
    }),
    ("lighthouse", { c, r in
        vertical(c, [0xF7C59F, 0xA9C9E8, 0x6FA3D6], CGRect(x: 0, y: 700, width: W, height: H - 700))
        vertical(c, [0x24557A, 0x3F78A0], CGRect(x: 0, y: 0, width: W, height: 720))
        ridge(c, base: 500, height: 160, roughness: 5, color: rgb(0x3B3A3F), rng: &r)
        let x: CGFloat = 1050
        c.setFillColor(rgb(0xF4F1EA)); c.fill(CGRect(x: x - 70, y: 620, width: 140, height: 640))
        for i in 0..<3 { c.setFillColor(rgb(0xD64545)); c.fill(CGRect(x: x - 70, y: 700 + CGFloat(i) * 200, width: 140, height: 80)) }
        c.setFillColor(rgb(0x2E2E33)); c.fill(CGRect(x: x - 90, y: 1260, width: 180, height: 30))
        glow(c, x, 1340, 360, 0xFFF3B0); circle(c, x, 1340, 50, rgb(0xFFF6CF))
    }),
    ("coffee_table", { c, r in
        vertical(c, [0x9C6B45, 0xB98457], CGRect(x: 0, y: 0, width: W, height: H))
        for i in 0..<9 { c.setStrokeColor(rgb(0x7A5034, 0.35)); c.setLineWidth(4); c.move(to: CGPoint(x: 0, y: CGFloat(i) * 240 + r.range(0, 60))); c.addLine(to: CGPoint(x: W, y: CGFloat(i) * 240 + r.range(0, 60))); c.strokePath() }
        circle(c, 620, 1180, 330, rgb(0xFAF7F2)); circle(c, 620, 1180, 230, rgb(0xF2EEE8))
        circle(c, 620, 1180, 200, rgb(0x5A3622)); circle(c, 620, 1180, 120, rgb(0x8B5A3C))
        c.setFillColor(rgb(0xFAF7F2)); c.fill(CGRect(x: 900, y: 1150, width: 140, height: 60))
        c.setFillColor(rgb(0xE4A853)); c.fillEllipse(in: CGRect(x: 820, y: 380, width: 480, height: 260))
        c.setFillColor(rgb(0xC98A3A)); for i in 0..<4 { c.fillEllipse(in: CGRect(x: 880 + CGFloat(i) * 95, y: 430, width: 60, height: 160)) }
    }),
    ("rainy_window", { c, r in
        vertical(c, [0x5A6B82, 0x8796AA, 0xA9B4C2], CGRect(x: 0, y: 0, width: W, height: H))
        for _ in 0..<18 { glow(c, r.range(0, W), r.range(0, 900), r.range(80, 200), [0xFFC46B, 0xFF7A7A, 0x7AD7FF][Int(r.range(0, 2.99))]) }
        for _ in 0..<160 { let x = r.range(0, W), y = r.range(0, H), s = r.range(6, 22); c.setFillColor(rgb(0xFFFFFF, 0.28)); c.fillEllipse(in: CGRect(x: x, y: y, width: s, height: s * 1.3)) }
    }),
    ("golden_bridge", { c, r in
        vertical(c, [0xFFB36B, 0xF0836B, 0x9E5E8E], CGRect(x: 0, y: 600, width: W, height: H - 600))
        vertical(c, [0x4C3B6B, 0x7A5A86], CGRect(x: 0, y: 0, width: W, height: 620))
        circle(c, 750, 900, 130, rgb(0xFFE3B3, 0.95))
        c.setFillColor(rgb(0x3A1F2E))
        for x in [380.0, 1120.0] as [CGFloat] { c.fill(CGRect(x: x - 30, y: 520, width: 60, height: 900)) }
        c.fill(CGRect(x: 0, y: 760, width: W, height: 36))
        c.setStrokeColor(rgb(0x3A1F2E)); c.setLineWidth(10)
        c.move(to: CGPoint(x: 0, y: 1250)); c.addQuadCurve(to: CGPoint(x: 380, y: 1400), control: CGPoint(x: 200, y: 900))
        c.addQuadCurve(to: CGPoint(x: 1120, y: 1400), control: CGPoint(x: 750, y: 700))
        c.addQuadCurve(to: CGPoint(x: 1500, y: 1250), control: CGPoint(x: 1300, y: 900)); c.strokePath()
    }),
    ("rolling_hills", { c, r in
        vertical(c, [0xD9F0FF, 0xA6D8F7], CGRect(x: 0, y: 0, width: W, height: H))
        for _ in 0..<4 { let x = r.range(100, 1400), y = r.range(1450, 1850); for d in 0..<3 { circle(c, x + CGFloat(d) * 70, y + (d == 1 ? 30 : 0), 70, rgb(0xFFFFFF, 0.9)) } }
        ridge(c, base: 900, height: 200, roughness: 3, color: rgb(0x9CCB6B), rng: &r, smooth: true)
        ridge(c, base: 600, height: 220, roughness: 3, color: rgb(0x6FAF4F), rng: &r, smooth: true)
        ridge(c, base: 280, height: 200, roughness: 3, color: rgb(0x4C8F3A), rng: &r, smooth: true)
        for i in 0..<3 { let x = 300 + CGFloat(i) * 380, y: CGFloat = 760 + CGFloat(i % 2) * 40
            c.setFillColor(rgb(0xF7F3EC)); c.fill(CGRect(x: x, y: y, width: 110, height: 80))
            c.setFillColor(rgb(0xC0504D)); let roof = CGMutablePath(); roof.move(to: CGPoint(x: x - 15, y: y + 80)); roof.addLine(to: CGPoint(x: x + 55, y: y + 140)); roof.addLine(to: CGPoint(x: x + 125, y: y + 80)); roof.closeSubpath(); c.addPath(roof); c.fillPath() }
    }),
    ("campfire", { c, r in
        vertical(c, [0x0B0F2A, 0x1F2550, 0x3A2F5B], CGRect(x: 0, y: 0, width: W, height: H))
        stars(c, 200, minY: 800, rng: &r)
        ridge(c, base: 420, height: 120, roughness: 10, color: rgb(0x111628), rng: &r)
        glow(c, 900, 420, 520, 0xFF9A3C)
        let tent = CGMutablePath(); tent.move(to: CGPoint(x: 260, y: 360)); tent.addLine(to: CGPoint(x: 560, y: 860)); tent.addLine(to: CGPoint(x: 860, y: 360)); tent.closeSubpath()
        c.setFillColor(rgb(0xE07A3F)); c.addPath(tent); c.fillPath()
        circle(c, 1000, 440, 70, rgb(0xFFC15E)); circle(c, 1000, 470, 40, rgb(0xFFF0B0))
    }),
    ("snowy_peaks", { c, r in
        vertical(c, [0x8FB8E8, 0xD8E9F8], CGRect(x: 0, y: 0, width: W, height: H))
        var cap = r
        ridge(c, base: 1000, height: 560, roughness: 7, color: rgb(0x7D93AD), rng: &r)
        c.saveGState(); c.clip(to: CGRect(x: 0, y: 1300, width: W, height: 700))
        ridge(c, base: 1000, height: 560, roughness: 7, color: rgb(0xF5F8FC), rng: &cap)
        c.restoreGState()
        ridge(c, base: 500, height: 260, roughness: 10, color: rgb(0x4E6680), rng: &r)
        vertical(c, [0xE9F1F8, 0xFFFFFF], CGRect(x: 0, y: 0, width: W, height: 420))
    })
]

let ci = CIContext()
for (index, (name, draw)) in scenes.enumerated() {
    let ctx = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    var rng = RNG(state: UInt64(index + 1) &* 0x9E3779B97F4A7C15)
    draw(ctx, &rng)
    var image = CIImage(cgImage: ctx.makeImage()!)
    // A touch of grain and vignette so they read as photos, not flat art
    let grain = CIFilter(name: "CIRandomGenerator")!.outputImage!.cropped(to: image.extent)
        .applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0), "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0), "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.035)
        ])
    image = grain.composited(over: image)
    image = image.applyingFilter("CIVignette", parameters: [kCIInputIntensityKey: 0.6, kCIInputRadiusKey: 2.2])
        .applyingGaussianBlur(sigma: 0.6).cropped(to: CGRect(x: 0, y: 0, width: W, height: H))
    let url = URL(fileURLWithPath: outDir).appendingPathComponent(String(format: "%02d_%@.jpg", index, name))
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ci.createCGImage(image, from: image.extent)!, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
    CGImageDestinationFinalize(dest)
}
print("rendered \(scenes.count) scenes")
