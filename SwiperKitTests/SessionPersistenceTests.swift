import XCTest
@testable import SwiperKit

final class SessionPersistenceTests: XCTestCase {
    private func makeDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiperTests-\(UUID().uuidString)", isDirectory: true)
    }

    // MARK: - Session round trips

    func testEngineRoundTripsThroughPersistedSession() {
        var engine = SessionEngine(order: TestLibrary.order(), direction: .older)
        engine.start()
        engine.apply(.keep)
        engine.apply(.queueDeletion)
        engine.apply(.favorite)

        let persisted = engine.persisted()
        let restored = SessionEngine.restored(
            from: persisted,
            order: TestLibrary.order(),
            marks: engine.queue.ids
        )
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

    func testPersistedSessionDoesNotCarryTheDeletionList() throws {
        var engine = SessionEngine(order: TestLibrary.order())
        engine.start()
        engine.apply(.queueDeletion)
        XCTAssertFalse(engine.queue.isEmpty)

        let data = try JSONEncoder().encode(engine.persisted())
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        XCTAssertNil(object["queueIDs"], "the deletion list is stored once, at the top level")
        XCTAssertNil(object["marks"])
    }

    func testResumableFlag() {
        XCTAssertFalse(PersistedSession().isResumable)
        XCTAssertTrue(PersistedSession(currentAssetID: "a").isResumable)
        XCTAssertTrue(PersistedSession(decidedIDs: ["a"]).isResumable)
        XCTAssertTrue(PersistedSession(decidedIDs: ["a"], isFinished: true).isResumable)
        XCTAssertFalse(PersistedSession(isFinished: true).isResumable)
    }

    func testStateResumabilityAndEmptiness() {
        XCTAssertFalse(PersistedState().isResumable)
        XCTAssertTrue(PersistedState().isEmpty)
        XCTAssertTrue(PersistedState(marks: ["a"]).isResumable == false)
        XCTAssertFalse(PersistedState(marks: ["a"]).isEmpty)
        XCTAssertTrue(PersistedState(session: PersistedSession(currentAssetID: "a")).isResumable)
    }

    // MARK: - File store

    func testFileSessionStoreRoundTrip() async throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = FileSessionStore(directory: directory)
        XCTAssertEqual(store.loadState(), .absent)
        XCTAssertEqual(store.loadStatistics(), .empty)
        XCTAssertEqual(store.loadPreferences(), .default)

        let state = PersistedState(
            marks: ["b"],
            session: PersistedSession(currentAssetID: "c", direction: .newer, decidedIDs: ["a", "b"])
        )
        try await store.saveState(state)
        XCTAssertEqual(store.loadState(), .loaded(state))
        XCTAssertEqual(FileSessionStore(directory: directory).loadState(), .loaded(state))

        var statistics = SessionStatistics.empty
        statistics.record(DeletionOutcome(requestedIDs: ["a"], deletedIDs: ["a"], failedIDs: [], deletedBytes: 4_000))
        store.saveStatistics(statistics)
        XCTAssertEqual(store.loadStatistics(), statistics)

        store.savePreferences(ControlPreferences(preset: .deleteOnly, placement: .left))
        XCTAssertEqual(store.loadPreferences(), ControlPreferences(preset: .deleteOnly, placement: .left))

        try await store.clearState()
        XCTAssertEqual(store.loadState(), .absent)
        XCTAssertNil(FileSessionStore(directory: directory).loadState().state)
    }

    func testClearingStateKeepsStatisticsAndPreferences() async throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = FileSessionStore(directory: directory)
        var statistics = SessionStatistics.empty
        statistics.record(DeletionOutcome(requestedIDs: ["a"], deletedIDs: ["a"], failedIDs: [], deletedBytes: 7))
        store.saveStatistics(statistics)
        store.savePreferences(ControlPreferences(preset: .thumb))
        try await store.saveState(PersistedState(marks: ["a"]))

        try await store.clearState()

        XCTAssertEqual(store.loadStatistics(), statistics)
        XCTAssertEqual(store.loadPreferences().preset, .thumb)
    }

    func testAFailedWriteIsReportedRatherThanSwallowed() async throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = FileSessionStore(directory: directory)
        let first = PersistedState(marks: ["a"], session: PersistedSession(currentAssetID: "a"))
        try await store.saveState(first)

        // Replace the directory with a regular file, so nothing can be written
        // inside it any more.
        try FileManager.default.removeItem(at: directory)
        try Data("blocked".utf8).write(to: directory)
        defer { try? FileManager.default.removeItem(at: directory) }

        do {
            try await store.saveState(PersistedState(marks: ["a", "b"]))
            XCTFail("a failed write must throw rather than be swallowed")
        } catch {
            guard case SessionStoreError.writeFailed = error else {
                return XCTFail("unexpected error \(error)")
            }
        }
    }

    // MARK: - Schema versioning and migration

    func testLegacyUnversionedSessionIsMigratedWithItsQueueAsMarks() throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let legacy = """
        {
          "currentAssetID": "c",
          "currentAssetDate": 0,
          "direction": "older",
          "mode": "sequential",
          "decidedIDs": ["b", "c"],
          "keptIDs": ["c"],
          "queueIDs": ["b"],
          "undoEntries": [],
          "updatedAt": 0,
          "isFinished": false
        }
        """
        try Data(legacy.utf8).write(to: directory.appendingPathComponent("session.json"))

        let store = FileSessionStore(directory: directory)
        guard case .migrated(let state) = store.loadState() else {
            return XCTFail("legacy state should be reported as migrated, got \(store.loadState())")
        }
        XCTAssertEqual(state.schemaVersion, PersistedState.currentSchemaVersion)
        XCTAssertEqual(state.marks, ["b"], "legacy queueIDs become the durable deletion list")
        XCTAssertEqual(state.session?.currentAssetID, "c")
        XCTAssertEqual(state.session?.decidedIDs, ["b", "c"])
        XCTAssertEqual(state.session?.keptIDs, ["c"])
    }

    func testMigratingWritesOnlyAfterASuccessfulSave() async throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("session.json")
        let legacy = #"{"currentAssetID":"c","queueIDs":["b"],"decidedIDs":["c"]}"#
        try Data(legacy.utf8).write(to: fileURL)

        let store = FileSessionStore(directory: directory)
        guard case .migrated(let state) = store.loadState() else {
            return XCTFail("expected a migration")
        }
        // The old bytes are untouched until the caller persists the upgrade.
        XCTAssertTrue(String(decoding: try Data(contentsOf: fileURL), as: UTF8.self).contains("queueIDs"))

        try await store.saveState(state)
        let upgraded = String(decoding: try Data(contentsOf: fileURL), as: UTF8.self)
        XCTAssertTrue(upgraded.contains("schemaVersion"))
        XCTAssertFalse(upgraded.contains("queueIDs"))
        XCTAssertEqual(FileSessionStore(directory: directory).loadState(), .loaded(state))
    }

    func testCorruptFileIsReportedAsUnreadableNotAsAnAbsentSession() throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("this is not json at all".utf8)
            .write(to: directory.appendingPathComponent("session.json"))

        let store = FileSessionStore(directory: directory)
        guard case .unreadable = store.loadState() else {
            return XCTFail("corrupt data must be unreadable, got \(store.loadState())")
        }
        XCTAssertFalse(store.loadState().allowsWrites)
    }

    func testWritesAreRefusedWhileUnreadableDataIsInTheWay() async throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("session.json")
        let original = "not json"
        try Data(original.utf8).write(to: fileURL)

        let store = FileSessionStore(directory: directory)
        do {
            try await store.saveState(PersistedState(marks: ["a"]))
            XCTFail("writing over unreadable data must fail")
        } catch {
            XCTAssertEqual(error as? SessionStoreError, .stateIsUnreadable)
        }
        XCTAssertEqual(String(decoding: try Data(contentsOf: fileURL), as: UTF8.self), original)

        do {
            try await store.clearState()
            XCTFail("clearing unreadable data must fail")
        } catch {
            XCTAssertEqual(error as? SessionStoreError, .stateIsUnreadable)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testQuarantinePreservesTheUnreadableFileAndUnblocksWrites() async throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let original = "still not json"
        try Data(original.utf8).write(to: directory.appendingPathComponent("session.json"))

        let store = FileSessionStore(directory: directory)
        let moved = try XCTUnwrap(store.quarantineUnreadableState())
        XCTAssertEqual(String(decoding: try Data(contentsOf: moved), as: UTF8.self), original)
        XCTAssertEqual(store.loadState(), .absent)

        try await store.saveState(PersistedState(marks: ["a"]))
        XCTAssertEqual(store.loadState().state?.marks, ["a"])
    }

    func testFutureSchemaVersionIsDistinguishableAndProtected() async throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("session.json")
        let future = #"{"schemaVersion":99,"marks":["a"],"updatedAt":0}"#
        try Data(future.utf8).write(to: fileURL)

        let store = FileSessionStore(directory: directory)
        guard case .unsupportedVersion(let found, let supported) = store.loadState() else {
            return XCTFail("a newer schema must be reported as unsupported, got \(store.loadState())")
        }
        XCTAssertEqual(found, 99)
        XCTAssertEqual(supported, PersistedState.currentSchemaVersion)
        XCTAssertFalse(store.loadState().allowsWrites)

        do {
            try await store.saveState(PersistedState(marks: ["b"]))
            XCTFail("a newer-version file must not be overwritten")
        } catch {
            XCTAssertEqual(
                error as? SessionStoreError,
                .stateIsFromNewerVersion(found: 99, supported: PersistedState.currentSchemaVersion)
            )
        }
        XCTAssertEqual(String(decoding: try Data(contentsOf: fileURL), as: UTF8.self), future)
    }

    func testKnownOlderSchemaVersionIsMigrated() throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let older = #"{"schemaVersion":1,"marks":["a"],"session":null,"updatedAt":0}"#
        try Data(older.utf8).write(to: directory.appendingPathComponent("session.json"))

        let store = FileSessionStore(directory: directory)
        guard case .migrated(let state) = store.loadState() else {
            return XCTFail("schema 1 should be migrated, got \(store.loadState())")
        }
        XCTAssertEqual(state.schemaVersion, PersistedState.currentSchemaVersion)
        XCTAssertEqual(state.marks, ["a"])
    }

    // MARK: - In-memory store

    func testInMemoryStoreRoundTrip() async throws {
        let store = InMemorySessionStore()
        XCTAssertEqual(store.loadState(), .absent)

        let state = PersistedState(marks: ["b"], session: PersistedSession(currentAssetID: "a"))
        try await store.saveState(state)
        XCTAssertEqual(store.loadState(), .loaded(state))

        try await store.clearState()
        XCTAssertEqual(store.loadState(), .absent)
    }

    func testInMemoryStoreCanFailWritesOnDemand() async {
        let store = InMemorySessionStore()
        store.failsWrites = true
        do {
            try await store.saveState(PersistedState(marks: ["a"]))
            XCTFail("expected the injected failure")
        } catch {
            XCTAssertEqual(error as? SessionStoreError, .writeFailed("test failure"))
        }
        XCTAssertEqual(store.saveAttempts, 1)
        XCTAssertTrue(store.savedStates.isEmpty)
    }

    func testInMemoryStoreRefusesToOverwriteUnreadableContent() async {
        let store = InMemorySessionStore(content: .unreadable)
        do {
            try await store.saveState(PersistedState(marks: ["a"]))
            XCTFail("expected the write to be refused")
        } catch {
            XCTAssertEqual(error as? SessionStoreError, .stateIsUnreadable)
        }
    }
}
