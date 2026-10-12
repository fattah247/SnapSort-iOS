//
//  ImageMetrics.swift
//  SnapSort
//
//  Pixel statistics used by photo analysis. Pure functions on CGImage so they
//  behave identically on device, in the simulator, and in calibration runs.
//
//  Thresholds in `Constants.Analysis` were calibrated against ~160 real photos
//  plus blurred, darkened and over-exposed variants of each.
//

import CoreGraphics
import Foundation

enum ImageMetrics {
    /// Renders `image` into an 8-bit grayscale buffer whose long side is at most `maxSide`.
    static func grayscale(_ image: CGImage, maxSide: Int) -> (pixels: [UInt8], width: Int, height: Int)? {
        let scale = min(1, Double(maxSide) / Double(max(image.width, image.height)))
        let width = max(1, Int((Double(image.width) * scale).rounded()))
        let height = max(1, Int((Double(image.height) * scale).rounded()))
        var pixels = [UInt8](repeating: 0, count: width * height)
        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return false }
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return drawn ? (pixels, width, height) : nil
    }

    /// Perceptual blur (Crété-Roffet et al., 2007): re-blurs the image and measures
    /// how much edge energy survives. 0 = crisp, 1 = completely smeared. Unlike raw
    /// Laplacian variance it barely depends on how much texture a photo has, so a
    /// sharp beach shot with a plain sky isn't mistaken for a blurry one.
    static func blurriness(_ image: CGImage, maxSide: Int = 1024) -> Float {
        guard let (pixels, width, height) = grayscale(image, maxSide: maxSide),
              width > 20, height > 20 else { return 0 }

        let radius = 4
        let taps = Double(2 * radius + 1)
        var sumFV = 0.0, sumVV = 0.0, sumFH = 0.0, sumVH = 0.0

        pixels.withUnsafeBufferPointer { f in
            // Vertical differences against a vertically box-blurred copy
            for x in 0..<width {
                var window = 0
                for k in 0...(2 * radius) { window += Int(f[k * width + x]) }
                var previousBlur = Double(window) / taps
                for y in (radius + 1)..<(height - radius) {
                    window += Int(f[(y + radius) * width + x]) - Int(f[(y - radius - 1) * width + x])
                    let blurred = Double(window) / taps
                    let dF = abs(Double(f[y * width + x]) - Double(f[(y - 1) * width + x]))
                    let dB = abs(blurred - previousBlur)
                    sumFV += dF
                    sumVV += max(0, dF - dB)
                    previousBlur = blurred
                }
            }

            // Horizontal differences against a horizontally box-blurred copy
            for y in 0..<height {
                let row = y * width
                var window = 0
                for k in 0...(2 * radius) { window += Int(f[row + k]) }
                var previousBlur = Double(window) / taps
                for x in (radius + 1)..<(width - radius) {
                    window += Int(f[row + x + radius]) - Int(f[row + x - radius - 1])
                    let blurred = Double(window) / taps
                    let dF = abs(Double(f[row + x]) - Double(f[row + x - 1]))
                    let dB = abs(blurred - previousBlur)
                    sumFH += dF
                    sumVH += max(0, dF - dB)
                    previousBlur = blurred
                }
            }
        }

        // A perfectly flat image has no edges to judge
        guard sumFV > 0, sumFH > 0 else { return 0 }
        let blurV = (sumFV - sumVV) / sumFV
        let blurH = (sumFH - sumVH) / sumFH
        return Float(max(blurV, blurH))
    }

    struct Exposure {
        /// Mean luminance, 0…1
        let mean: Float
        /// Standard deviation of luminance, 0…1 (how much contrast there is)
        let spread: Float
        /// Share of pixels that are nearly black
        let crushedShadows: Float
        /// Share of pixels that are nearly white
        let blownHighlights: Float

        /// Dark *and* flat — a pocket shot or lens cap, not a night scene with lights
        var isTooDark: Bool {
            mean < Constants.Analysis.darkMeanThreshold && spread < Constants.Analysis.darkSpreadThreshold
        }

        /// Large washed-out areas on an already bright frame
        var isTooBright: Bool {
            blownHighlights > Constants.Analysis.blownHighlightThreshold && mean > Constants.Analysis.brightMeanThreshold
        }
    }

    static func exposure(_ image: CGImage) -> Exposure? {
        guard let (pixels, _, _) = grayscale(image, maxSide: 64), !pixels.isEmpty else { return nil }
        var sum = 0.0
        var squares = 0.0
        var dark = 0
        var bright = 0
        for pixel in pixels {
            let value = Double(pixel) / 255
            sum += value
            squares += value * value
            if pixel < 16 { dark += 1 }
            if pixel > 245 { bright += 1 }
        }
        let count = Double(pixels.count)
        let mean = sum / count
        let variance = max(0, squares / count - mean * mean)
        return Exposure(
            mean: Float(mean),
            spread: Float(variance.squareRoot()),
            crushedShadows: Float(Double(dark) / count),
            blownHighlights: Float(Double(bright) / count)
        )
    }
}

extension ImageMetrics {
    /// 64-bit difference hash: each bit says whether a pixel is brighter than its
    /// right-hand neighbour on a 9×8 thumbnail. Robust to resizing, small crops,
    /// exposure tweaks and blur, so retakes land within a few bits of each other.
    static func differenceHash(_ image: CGImage) -> UInt64? {
        let width = 9, height = 8
        var pixels = [UInt8](repeating: 0, count: width * height)
        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }

        var hash: UInt64 = 0
        for y in 0..<height {
            for x in 0..<(width - 1) {
                hash <<= 1
                if pixels[y * width + x] > pixels[y * width + x + 1] { hash |= 1 }
            }
        }
        return hash
    }
}
