import XCTest
@testable import SwiperKit

final class SessionPersistenceTests: XCTestCase {
    func testEngineRoundTripsThroughPersistedSession() {
        var engine = SessionEngine(order: TestLibrary.order(), direction: .older)
        engine.start()
        engine.apply(.keep)
        engine.apply(.queueDeletion)
        engine.apply(.favorite)

        let persisted = engine.persisted()
        let restored = SessionEngine.restored(from: persisted, order: TestLibrary.order())
        XCTAssertEqual(restored.current?.id, engine.current?.id)
        XCTAssertEqual(restored.queue.ids, engine.queue.ids)
        XCTAssertEqual(restored.decidedIDs, engine.decidedIDs)
        XCTAssertEqual(restored.keptIDs, engine.keptIDs)
        XCTAssertEqual(restored.undoStack.entries, engine.undoStack.entries)
        XCTAssertEqual(restored.direction, engine.direction)
    }

    func testPersistedSessionCodableRoundTrip() throws {
        var engine = SessionEngine(order: TestLibrary.order(), mode: .tumbler, tumblerSeed: 11)
        engine.start()
        engine.apply(.keep)
        let persisted = engine.persisted()
        let data = try JSONEncoder().encode(persisted)
        let decoded = try JSONDecoder().decode(PersistedSession.self, from: data)
        XCTAssertEqual(decoded, persisted)
        XCTAssertEqual(decoded.mode, .tumbler)
        XCTAssertNotNil(decoded.tumbler)
    }

    func testResumableFlag() {
        XCTAssertFalse(PersistedSession().isResumable)
        XCTAssertTrue(PersistedSession(currentAssetID: "a").isResumable)
        XCTAssertTrue(PersistedSession(decidedIDs: ["a"]).isResumable)
        XCTAssertTrue(PersistedSession(queueIDs: ["a"]).isResumable)
        XCTAssertTrue(PersistedSession(queueIDs: ["a"], isFinished: true).isResumable)
        XCTAssertFalse(PersistedSession(isFinished: true).isResumable)
    }

    func testFileSessionStoreRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiperTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = FileSessionStore(directory: directory)
        XCTAssertNil(store.loadSession())
        XCTAssertEqual(store.loadStatistics(), .empty)
        XCTAssertEqual(store.loadPreferences(), .default)

        let session = PersistedSession(currentAssetID: "c", direction: .newer, decidedIDs: ["a", "b"], queueIDs: ["b"])
        store.saveSession(session)
        XCTAssertEqual(store.loadSession(), session)

        var statistics = SessionStatistics.empty
        statistics.record(DeletionOutcome(requestedIDs: ["a"], deletedIDs: ["a"], failedIDs: [], deletedBytes: 4_000))
        store.saveStatistics(statistics)
        XCTAssertEqual(store.loadStatistics(), statistics)

        store.savePreferences(ControlPreferences(preset: .deleteOnly, placement: .left))
        XCTAssertEqual(store.loadPreferences(), ControlPreferences(preset: .deleteOnly, placement: .left))

        store.clearSession()
        XCTAssertNil(store.loadSession())
    }

    func testInMemoryStoreRoundTrip() {
        let store = InMemorySessionStore()
        let session = PersistedSession(currentAssetID: "a", decidedIDs: ["a"])
        store.saveSession(session)
        XCTAssertEqual(store.loadSession(), session)
        store.clearSession()
        XCTAssertNil(store.loadSession())
    }

    func testFileSessionStoreFlushesLatestQueuedWrite() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiperTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = FileSessionStore(directory: directory)
        for index in 0..<100 {
            store.saveSession(PersistedSession(currentAssetID: "asset-\(index)"))
        }
        store.flushSessionWrites()

        XCTAssertEqual(store.loadSession()?.currentAssetID, "asset-99")
    }
}
