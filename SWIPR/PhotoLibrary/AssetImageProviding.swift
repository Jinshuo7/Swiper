import Photos
import UIKit

/// Image-specific operations, kept separate from `PhotoLibraryProviding` so the
/// logic framework stays free of UIKit types.
protocol AssetImageProviding: AnyObject {
    func displayImage(for id: String, targetSize: CGSize) async -> UIImage?
    func thumbnail(for id: String, targetSize: CGSize) async -> UIImage?
    func livePhoto(for id: String, targetSize: CGSize) async -> PHLivePhoto?
    func startCaching(ids: [String], targetSize: CGSize)
    func stopCaching(ids: [String], targetSize: CGSize)
}

/// Thread-safe bridge that lets a `PHImageManager` callback and Swift task
/// cancellation race to resolve an async request exactly once.
final class AsyncRequestBridge<Value> {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value?, Never>?
    private var storedResult: Value??
    private var resolved = false
    private var requestID: PHImageRequestID?
    private weak var manager: PHCachingImageManager?

    func attach(continuation: CheckedContinuation<Value?, Never>, manager: PHCachingImageManager) {
        lock.lock()
        self.manager = manager
        if let result = storedResult {
            resolved = true
            lock.unlock()
            continuation.resume(returning: result)
            return
        }
        self.continuation = continuation
        lock.unlock()
    }

    func setRequestID(_ id: PHImageRequestID) {
        lock.lock()
        if resolved {
            let manager = self.manager
            lock.unlock()
            manager?.cancelImageRequest(id)
            return
        }
        requestID = id
        lock.unlock()
    }

    func resolve(_ value: Value?) {
        lock.lock()
        if resolved {
            lock.unlock()
            return
        }
        resolved = true
        if let continuation {
            self.continuation = nil
            lock.unlock()
            continuation.resume(returning: value)
        } else {
            storedResult = value
            lock.unlock()
        }
    }

    func cancel() {
        lock.lock()
        let id = requestID
        let manager = self.manager
        lock.unlock()
        if let id { manager?.cancelImageRequest(id) }
        resolve(nil)
    }
}
