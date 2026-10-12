//
//  ZoomableImageView.swift
//  SnapSort
//
//  UIScrollView-backed image view for native pinch, pan, bounce and
//  double-tap zoom. At 1x it doesn't scroll, so sheet dismissal still works.
//

import SwiftUI
import UIKit

struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> ZoomingScrollView {
        ZoomingScrollView()
    }

    func updateUIView(_ view: ZoomingScrollView, context: Context) {
        view.setImage(image)
    }
}

final class ZoomingScrollView: UIScrollView, UIScrollViewDelegate {
    private let imageView = UIImageView()
    private var lastLayoutSize: CGSize = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        delegate = self
        minimumZoomScale = 1
        maximumZoomScale = 4
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        decelerationRate = .fast
        contentInsetAdjustmentBehavior = .never
        backgroundColor = .clear

        imageView.contentMode = .scaleAspectFit
        imageView.isAccessibilityElement = true
        imageView.accessibilityTraits = .image
        imageView.accessibilityLabel = "Photo"
        addSubview(imageView)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setImage(_ image: UIImage) {
        guard imageView.image !== image else { return }
        let previous = imageView.image
        imageView.image = image
        // Keep the user's zoom when a sharper copy of the same framing arrives;
        // refit when the shape changes (fast thumbnails are often square crops)
        if previous == nil || !Self.hasSameAspectRatio(previous!.size, image.size) {
            lastLayoutSize = .zero
            setNeedsLayout()
        }
    }

    private static func hasSameAspectRatio(_ lhs: CGSize, _ rhs: CGSize) -> Bool {
        guard lhs.height > 0, rhs.height > 0 else { return false }
        return abs(lhs.width / lhs.height - rhs.width / rhs.height) < 0.01
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let image = imageView.image, bounds.width > 0, bounds.height > 0 else { return }

        if lastLayoutSize != bounds.size {
            lastLayoutSize = bounds.size
            zoomScale = minimumZoomScale
            let fitted = fittedSize(for: image.size, in: bounds.size)
            imageView.frame = CGRect(origin: .zero, size: fitted)
            contentSize = fitted
        }
        centerContent()
    }

    private func fittedSize(for imageSize: CGSize, in container: CGSize) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else { return container }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    private func centerContent() {
        let horizontal = max(0, (bounds.width - contentSize.width) / 2)
        let vertical = max(0, (bounds.height - contentSize.height) / 2)
        contentInset = UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
    }

    // MARK: - UIScrollViewDelegate

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerContent()
    }

    // MARK: - Double Tap

    @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        if zoomScale > minimumZoomScale {
            setZoomScale(minimumZoomScale, animated: true)
            return
        }
        let point = recognizer.location(in: imageView)
        let targetScale = min(maximumZoomScale, 2.5)
        let size = CGSize(width: bounds.width / targetScale, height: bounds.height / targetScale)
        let rect = CGRect(
            x: point.x - size.width / 2,
            y: point.y - size.height / 2,
            width: size.width,
            height: size.height
        )
        zoom(to: rect, animated: true)
    }
}
