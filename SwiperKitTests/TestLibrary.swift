import Foundation
@testable import SwiperKit

/// Builds a deterministic, evenly spaced library for tests.
enum TestLibrary {
    static func descriptor(
        id: String,
        dayOffset: Int,
        width: Int = 4_032,
        height: Int = 3_024,
        favorite: Bool = false,
        kind: MediaKind = .photo
    ) -> AssetDescriptor {
        let base = Date(timeIntervalSince1970: 1_600_000_000)
        return AssetDescriptor(
            id: id,
            creationDate: base.addingTimeInterval(Double(dayOffset) * 86_400),
            pixelWidth: width,
            pixelHeight: height,
            isFavorite: favorite,
            kind: kind
        )
    }

    /// `a` is oldest and `e` is newest.
    static func sequential() -> [AssetDescriptor] {
        [
            descriptor(id: "a", dayOffset: 0),
            descriptor(id: "b", dayOffset: 1),
            descriptor(id: "c", dayOffset: 2),
            descriptor(id: "d", dayOffset: 3),
            descriptor(id: "e", dayOffset: 4),
        ]
    }

    static func order() -> LibraryOrder { LibraryOrder(sequential()) }
}
