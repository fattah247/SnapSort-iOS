// Builds the demo photo library from the rendered scenes: photos spread over
// several years, bursts of near-identical shots, blurry, shaky, dark and
// overexposed shots, a receipt, a ticket with a QR code, and two videos.
// Capture dates are written to EXIF so Photos sorts them correctly.
//
// Usage: swift library.swift <scenes folder> <output folder>

import AppKit
import AVFoundation
import CoreImage
import ImageIO
import UniformTypeIdentifiers

let srcDir = CommandLine.arguments[1]
let outDir = CommandLine.arguments[2]
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
let ci = CIContext()
let files = try FileManager.default.contentsOfDirectory(atPath: srcDir).filter { $0.hasSuffix(".jpg") }.sorted()

let exifFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy:MM:dd HH:mm:ss"
    f.locale = Locale(identifier: "en_US_POSIX")
    return f
}()

func write(_ image: CIImage, name: String, date: Date) {
    guard let cg = ci.createCGImage(image, from: image.extent) else { return }
    let url = URL(fileURLWithPath: outDir).appendingPathComponent(name + ".jpg")
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { return }
    let stamp = exifFormatter.string(from: date)
    let props: [CFString: Any] = [
        kCGImageDestinationLossyCompressionQuality: 0.9,
        kCGImagePropertyExifDictionary: [
            kCGImagePropertyExifDateTimeOriginal: stamp,
            kCGImagePropertyExifDateTimeDigitized: stamp
        ],
        kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFDateTime: stamp]
    ]
    CGImageDestinationAddImage(dest, cg, props as CFDictionary)
    CGImageDestinationFinalize(dest)
}

func blur(_ image: CIImage, _ sigma: Double) -> CIImage {
    image.clampedToExtent().applyingGaussianBlur(sigma: sigma).cropped(to: image.extent)
}
func motion(_ image: CIImage, _ radius: Double) -> CIImage {
    let f = CIFilter(name: "CIMotionBlur")!
    f.setValue(image.clampedToExtent(), forKey: kCIInputImageKey)
    f.setValue(radius, forKey: kCIInputRadiusKey)
    return f.outputImage!.cropped(to: image.extent)
}
func exposure(_ image: CIImage, _ ev: Double) -> CIImage {
    image.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: ev])
}
func jitter(_ image: CIImage, _ amount: CGFloat, _ ev: Double) -> CIImage {
    let e = image.extent
    return exposure(image.cropped(to: e.insetBy(dx: e.width * amount, dy: e.height * amount)), ev)
}

let calendar = Calendar(identifier: .gregorian)
func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0, _ second: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
}

let images = files.compactMap { CIImage(contentsOf: URL(fileURLWithPath: srcDir + "/" + $0)) }
var n = 0
func next() -> CIImage { defer { n += 1 }; return images[(n * 7) % images.count] }

// Sharp photos spread across several years
for i in 0..<30 {
    let year = 2019 + i % 8
    // Repeats of a scene get their own crop and exposure, so they read as different shots
    let scene = next()
    write(i < 16 ? scene : jitter(scene, 0.12, i.isMultiple(of: 2) ? 0.2 : -0.2), name: "sharp_\(i)", date: date(year, 1 + i % 12, 1 + i % 27, 9 + i % 10, i))
}
// Blurry / shaky
for i in 0..<5 { write(blur(next(), 4), name: "blurry_\(i)", date: date(2025, 3, 2 + i, 15)) }
for i in 0..<3 { write(motion(next(), 30), name: "shaky_\(i)", date: date(2025, 4, 2 + i, 18)) }
// Pocket shots and overexposed
for i in 0..<3 { write(exposure(next(), -5), name: "dark_\(i)", date: date(2026, 2, 10 + i, 22)) }
for i in 0..<2 { write(exposure(next(), 3.2), name: "bright_\(i)", date: date(2026, 5, 4 + i, 13)) }
// Bursts of near-identical shots, seconds apart
for set in 0..<4 {
    let base = next()
    let start = date(2026, 6 + set, 3 + set, 10 + set, 15)
    for shot in 0..<(set == 0 ? 4 : 3) {
        let variant = shot == 0 ? base : (shot == 1 ? jitter(base, 0.03, 0.1) : (shot == 2 ? blur(jitter(base, 0.05, -0.1), 2.5) : jitter(base, 0.02, 0.2)))
        write(variant, name: "burst\(set)_\(shot)", date: start.addingTimeInterval(Double(shot) * 2))
    }
}

// Documents
func render(_ size: CGSize, _ draw: (CGContext) -> Void) -> CIImage {
    let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    draw(ctx)
    return CIImage(cgImage: ctx.makeImage()!)
}
func text(_ s: String, _ rect: CGRect, _ size: CGFloat, weight: NSFont.Weight = .regular) {
    (s as NSString).draw(in: rect, withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: size, weight: weight), .foregroundColor: NSColor.black])
}
let receiptLines = (1...14).map { "Item \($0) ............ \(String(format: "%.2f", Double($0) * 3.75))" }.joined(separator: "\n")
let receipt = render(CGSize(width: 1200, height: 1600)) { c in
    c.setFillColor(NSColor(calibratedRed: 0.42, green: 0.36, blue: 0.3, alpha: 1).cgColor); c.fill(CGRect(x: 0, y: 0, width: 1200, height: 1600))
    c.setFillColor(NSColor(white: 0.97, alpha: 1).cgColor); c.fill(CGRect(x: 180, y: 80, width: 840, height: 1440))
    text("CORNER CAFE", CGRect(x: 260, y: 1380, width: 700, height: 80), 54, weight: .bold)
    text("Receipt #20391", CGRect(x: 260, y: 1310, width: 700, height: 50), 30)
    text(receiptLines, CGRect(x: 240, y: 380, width: 760, height: 900), 30)
    text("TOTAL ........... 393.75", CGRect(x: 240, y: 260, width: 760, height: 60), 34, weight: .bold)
}
write(receipt, name: "receipt", date: date(2026, 8, 14, 13, 5))

let qr = CIFilter(name: "CIQRCodeGenerator")!
qr.setValue("https://example.com/ticket/88231".data(using: .utf8), forKey: "inputMessage")
let qrImage = qr.outputImage!.transformed(by: CGAffineTransform(scaleX: 22, y: 22))
let qrCG = ci.createCGImage(qrImage, from: qrImage.extent)!
let ticket = render(CGSize(width: 1200, height: 1600)) { c in
    c.setFillColor(NSColor(white: 0.93, alpha: 1).cgColor); c.fill(CGRect(x: 0, y: 0, width: 1200, height: 1600))
    text("CONCERT TICKET", CGRect(x: 200, y: 1400, width: 900, height: 80), 56, weight: .bold)
    text("Gate B · Row 12 · Seat 4", CGRect(x: 200, y: 1320, width: 900, height: 60), 34)
    c.draw(qrCG, in: CGRect(x: 300, y: 400, width: 600, height: 600))
}
write(ticket, name: "ticket", date: date(2026, 9, 20, 19, 30))

// Videos: one long, one short
func makeVideo(name: String, seconds: Int, frames: [CIImage], date: Date) {
    let url = URL(fileURLWithPath: outDir).appendingPathComponent(name + ".mov")
    try? FileManager.default.removeItem(at: url)
    let writer = try! AVAssetWriter(outputURL: url, fileType: .mov)
    let size = CGSize(width: 1280, height: 720)
    let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: size.width, AVVideoHeightKey: size.height
    ])
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
        kCVPixelBufferWidthKey as String: size.width, kCVPixelBufferHeightKey as String: size.height
    ])
    writer.add(input)
    let creation = AVMutableMetadataItem()
    creation.key = AVMetadataKey.commonKeyCreationDate as NSString
    creation.keySpace = .common
    creation.value = ISO8601DateFormatter().string(from: date) as NSString
    writer.metadata = [creation]
    writer.startWriting()
    writer.startSession(atSourceTime: .zero)
    for second in 0...seconds {
        while !input.isReadyForMoreMediaData { usleep(1000) }
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
        let frame = frames[second % frames.count]
        let scaled = frame.transformed(by: CGAffineTransform(scaleX: size.width / frame.extent.width, y: size.height / frame.extent.height))
        ci.render(scaled, to: buffer!)
        adaptor.append(buffer!, withPresentationTime: CMTime(value: CMTimeValue(second), timescale: 1))
    }
    input.markAsFinished()
    let done = DispatchSemaphore(value: 0)
    writer.finishWriting { done.signal() }
    done.wait()
}
makeVideo(name: "long_video", seconds: 75, frames: Array(images.prefix(5)), date: date(2026, 7, 4, 17))
makeVideo(name: "short_video", seconds: 8, frames: Array(images.dropFirst(5).prefix(3)), date: date(2026, 9, 1, 10))
print("done")
