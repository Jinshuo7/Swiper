import Photos

/// A UI-friendly mirror of `PHAuthorizationStatus` for the access level Swiper
/// actually needs (read-write, because favorites and deletion both mutate the
/// library).
enum LibraryAuthorization: Equatable {
    case notDetermined
    case denied
    case restricted
    case limited
    case authorized

    init(_ status: PHAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .denied: self = .denied
        case .restricted: self = .restricted
        case .limited: self = .limited
        case .authorized: self = .authorized
        @unknown default: self = .denied
        }
    }

    var canBrowse: Bool { self == .authorized || self == .limited }
    var isLimited: Bool { self == .limited }
}
