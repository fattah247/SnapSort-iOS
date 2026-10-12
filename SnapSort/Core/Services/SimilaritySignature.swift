//
//  SimilaritySignature.swift
//  SnapSort
//
//  What two photos are compared on when looking for similar shots.
//
//  Vision feature prints are the most accurate signal, but they need the
//  on-device ML runtime (unavailable in the Simulator, and occasionally
//  failing under memory pressure). A 64-bit difference hash is always
//  computed too, so similar-shot detection never silently goes dark.
//

import Foundation
import Vision

struct SimilaritySignature {
    let pixelHash: UInt64?
    let featurePrint: VNFeaturePrintObservation?

    /// Stored in `PhotoAnalysisEntity.featurePrintData`. Versioned with a magic
    /// prefix; older caches hold a bare archived feature print.
    private static let magic = Data("SSG1".utf8)

    init(pixelHash: UInt64?, featurePrint: VNFeaturePrintObservation?) {
        self.pixelHash = pixelHash
        self.featurePrint = featurePrint
    }

    init?(data: Data) {
        if data.starts(with: Self.magic) {
            var cursor = data.index(data.startIndex, offsetBy: Self.magic.count)
            guard data.distance(from: cursor, to: data.endIndex) >= 9 else { return nil }
            let hasHash = data[cursor] == 1
            cursor = data.index(after: cursor)
            let hashBytes = data[cursor..<data.index(cursor, offsetBy: 8)]
            pixelHash = hasHash ? hashBytes.reduce(UInt64(0)) { ($0 << 8) | UInt64($1) } : nil
            cursor = data.index(cursor, offsetBy: 8)
            let printData = data[cursor...]
            featurePrint = printData.isEmpty ? nil : try? NSKeyedUnarchiver.unarchivedObject(
                ofClass: VNFeaturePrintObservation.self,
                from: Data(printData)
            )
        } else {
            pixelHash = nil
            featurePrint = try? NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: data)
        }
        guard pixelHash != nil || featurePrint != nil else { return nil }
    }

    var data: Data? {
        guard pixelHash != nil || featurePrint != nil else { return nil }
        var data = Self.magic
        data.append(pixelHash == nil ? 0 : 1)
        let hash = pixelHash ?? 0
        for shift in stride(from: 56, through: 0, by: -8) {
            data.append(UInt8(truncatingIfNeeded: hash >> UInt64(shift)))
        }
        if let featurePrint,
           let archived = try? NSKeyedArchiver.archivedData(withRootObject: featurePrint, requiringSecureCoding: true) {
            data.append(archived)
        }
        return data
    }

    /// Whether two photos look like retakes of the same moment
    func isSimilar(to other: SimilaritySignature) -> Bool {
        if let lhs = featurePrint, let rhs = other.featurePrint {
            var distance: Float = .greatestFiniteMagnitude
            if (try? lhs.computeDistance(&distance, to: rhs)) != nil {
                return distance < Constants.Analysis.similarDistanceThreshold
            }
        }
        if let lhs = pixelHash, let rhs = other.pixelHash {
            return (lhs ^ rhs).nonzeroBitCount <= Constants.Analysis.similarHashThreshold
        }
        return false
    }
}
