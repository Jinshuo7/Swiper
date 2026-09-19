import Foundation

/// An honest, documented estimate of how many bytes an asset occupies.
///
/// **Why an estimate?** PhotoKit's supported public API does not expose an
/// asset's byte size. The private/KVC `PHAsset` filename + `FileManager`
/// attribute tricks that some apps use are not App Store safe, so Swiper does
/// not use them. Instead we derive a size from the asset's pixel dimensions and
/// media kind using average bitrates for Apple's default encodings.
///
/// The estimate is used only for user-facing "approximately reclaimed" copy and
/// for lifetime storage totals, never for deletion decisions.
///
/// Calculation:
/// * Still image: `pixels * stillBytesPerPixel`, floored at `minimumStillBytes`.
///   Apple's default HEIC encoder produces roughly 0.2–0.25 bytes per pixel for
///   typical camera output, so `0.22` is a reasonable central value
///   (≈2.6 MB for a 12 MP photo).
/// * Live Photo: the still plus the motion clip. A Live Photo's video
///   component is a short (~3 s) HEVC clip; we charge a flat
///   `livePhotoMotionBytes` (≈1.8 MB) on top of the still.
public enum StorageEstimate {
    /// Average bytes per pixel for an Apple HEIC still image.
    public static let stillBytesPerPixel: Double = 0.22
    /// Bytes attributed to the motion component of one Live Photo.
    public static let livePhotoMotionBytes: Int64 = 1_800_000
    /// Lower bound so zero/tiny pixel dimensions never report a silly size.
    public static let minimumStillBytes: Int64 = 200_000

    public static func bytes(width: Int, height: Int, kind: MediaKind) -> Int64 {
        let width = max(0, width)
        let height = max(0, height)
        let pixels = Int64(width) * Int64(height)
        let still = max(minimumStillBytes, Int64((Double(pixels) * stillBytesPerPixel).rounded()))
        switch kind {
        case .photo:
            return still
        case .livePhoto:
            return still + livePhotoMotionBytes
        }
    }

    public static func bytes(for descriptor: AssetDescriptor) -> Int64 {
        bytes(width: descriptor.pixelWidth, height: descriptor.pixelHeight, kind: descriptor.kind)
    }
}
