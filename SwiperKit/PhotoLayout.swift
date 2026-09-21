import CoreGraphics
import Foundation

/// Pure geometry for presenting a complete asset inside a bounded canvas.
///
/// The viewer must never crop a photo merely to fill the display: every asset
/// is contained at its original aspect ratio and centred against black. Keeping
/// that arithmetic here — rather than only inside a SwiftUI modifier — makes it
/// directly testable and lets the view size its canvas to exactly the fitted
/// rectangle.
public enum PhotoLayout {
    /// The largest size that shows all of a `pixelSize` asset inside `bounds`
    /// without cropping, preserving the asset's aspect ratio.
    ///
    /// Degenerate inputs (a zero or negative pixel dimension, or an empty
    /// bounds) return `bounds` so callers always get a usable size.
    public static func fittedSize(forPixelSize pixelSize: CGSize, in bounds: CGSize) -> CGSize {
        guard pixelSize.width > 0, pixelSize.height > 0 else { return bounds }
        return fittedSize(aspectRatio: pixelSize.width / pixelSize.height, in: bounds)
    }

    /// The largest size with `aspectRatio` (width ÷ height) that fits inside
    /// `bounds` without cropping.
    public static func fittedSize(aspectRatio: CGFloat, in bounds: CGSize) -> CGSize {
        guard aspectRatio > 0, aspectRatio.isFinite else { return bounds }
        guard bounds.width > 0, bounds.height > 0 else {
            return CGSize(width: max(0, bounds.width), height: max(0, bounds.height))
        }

        let boundsRatio = bounds.width / bounds.height
        if aspectRatio > boundsRatio {
            // Wider than the bounds: width-limited, letterboxed top and bottom.
            return CGSize(width: bounds.width, height: bounds.width / aspectRatio)
        } else {
            // Taller than the bounds: height-limited, pillarboxed left and right.
            return CGSize(width: bounds.height * aspectRatio, height: bounds.height)
        }
    }

    /// The fitted rectangle centred inside `bounds` (origin in `bounds`'
    /// coordinate space).
    public static func fittedRect(forPixelSize pixelSize: CGSize, in bounds: CGRect) -> CGRect {
        let size = fittedSize(forPixelSize: pixelSize, in: bounds.size)
        let x: CGFloat = bounds.minX + (bounds.width - size.width) / 2
        let y: CGFloat = bounds.minY + (bounds.height - size.height) / 2
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }

    /// Whether `size` is a faithful fit for an asset of `pixelSize` inside
    /// `bounds`: it preserves the asset's aspect ratio (within `tolerance`) and
    /// does not exceed the bounds.
    public static func fitsWithoutCropping(
        size: CGSize,
        pixelSize: CGSize,
        in bounds: CGSize,
        tolerance: CGFloat = 0.5
    ) -> Bool {
        guard size.width <= bounds.width + tolerance, size.height <= bounds.height + tolerance else {
            return false
        }
        guard pixelSize.width > 0, pixelSize.height > 0, size.height > 0 else { return false }
        let assetRatio = pixelSize.width / pixelSize.height
        let shownRatio = size.width / size.height
        guard abs(assetRatio - shownRatio) <= tolerance else { return false }
        let fitted = fittedSize(forPixelSize: pixelSize, in: bounds)
        return abs(fitted.width - size.width) <= tolerance && abs(fitted.height - size.height) <= tolerance
    }
}
