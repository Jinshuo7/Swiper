import XCTest
@testable import SWIPRKit

final class SessionPersistenceTests: XCTestCase {
    private func makeDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("SWIPRTests-\(UUID().uuidString)", isDirectory: true)
    }

    // MARK: - Session round trips

    func testEngineRoundTripsThroughPersistedSession() {
        var engine = SessionEngine(order: TestLibrary.order(), direction: .older)
        engine.start()
        engine.apply(.keep)
        engine.apply(.queueDeletion)
        engine.apply(.keep)

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

    /// A Random session is written to bytes, read back on the next launch, and
    /// walks exactly the order it had left — same seed, same pending members,
    /// same position, no repeats.
    func testTumblerOrderAndPositionSurviveTerminationAndRelaunch() throws {
        let library = TestLibrary.order()
        var engine = SessionEngine(order: library, mode: .tumbler, tumblerSeed: 4242)
        engine.start()
        engine.apply(.keep)
        engine.apply(.queueDeletion)
        let queued = engine.queue.ids

        // Terminate: the session becomes bytes on disk. Relaunch: the bytes are
        // decoded and the engine is rebuilt against the same library.
        let data = try JSONEncoder().encode(engine.persisted())
        let decoded = try JSONDecoder().decode(PersistedSession.self, from: data)
        var resumed = SessionEngine.restored(from: decoded, order: library, marks: queued)

        XCTAssertEqual(resumed.mode, .tumbler)
        XCTAssertEqual(resumed.current?.id, engine.current?.id, "the position survives")
        XCTAssertEqual(resumed.tumbler?.seed, engine.tumbler?.seed, "the seed survives")
        XCTAssertEqual(resumed.tumbler?.remaining, engine.tumbler?.remaining, "the pending order survives")
        XCTAssertEqual(resumed.tumbler?.handled, engine.tumbler?.handled)

        var original = engine
        var firstRun: [String] = []
        while let id = original.current?.id {
            firstRun.append(id)
            original.apply(.keep)
        }
        var secondRun: [String] = []
        while let id = resumed.current?.id {
            secondRun.append(id)
            resumed.apply(.keep)
        }
        XCTAssertEqual(firstRun, secondRun, "the resumed order is exactly the saved one")
        XCTAssertEqual(secondRun.count, Set(secondRun).count, "and never repeats")
        XCTAssertFalse(secondRun.contains(queued.first ?? ""))
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

        store.savePreferences(ControlPreferences(position: .leading, showButtons: false))
        XCTAssertEqual(
            store.loadPreferences(),
            ControlPreferences(position: .leading, showButtons: false)
        )

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
        store.savePreferences(ControlPreferences(position: .trailing))
        try await store.saveState(PersistedState(marks: ["a"]))

        try await store.clearState()

        XCTAssertEqual(store.loadStatistics(), statistics)
        XCTAssertEqual(store.loadPreferences().position, .trailing)
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

    // MARK: - A damaged save file is kept, never replaced with empty progress

    private func writeSessionFile(_ json: String, in directory: URL) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("session.json")
        try Data(json.utf8).write(to: url)
        return url
    }

    /// The file must read as unreadable, refuse writes, and stay byte-for-byte
    /// as it was, so a damaged save is never overwritten with empty progress.
    private func assertDamagedFileIsKept(
        _ json: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = try writeSessionFile(json, in: directory)
        let before = try Data(contentsOf: url)

        let store = FileSessionStore(directory: directory)

        guard case .unreadable = store.loadState() else {
            return XCTFail("expected unreadable, got \(store.loadState())", file: file, line: line)
        }
        XCTAssertFalse(store.loadState().allowsWrites, file: file, line: line)
        XCTAssertEqual(
            try Data(contentsOf: url),
            before,
            "the damaged file must be left byte-for-byte unchanged",
            file: file,
            line: line
        )
    }

    func testMissingSchemaVersionIsUnreadableAndKept() throws {
        try assertDamagedFileIsKept(#"{"marks":["a"],"session":null,"updatedAt":0}"#)
    }

    func testNullSchemaVersionIsUnreadableAndKept() throws {
        try assertDamagedFileIsKept(#"{"schemaVersion":null,"marks":["a"]}"#)
    }

    func testStringSchemaVersionIsUnreadableAndKept() throws {
        try assertDamagedFileIsKept(#"{"schemaVersion":"3","marks":["a"]}"#)
    }

    func testEmptyJSONObjectIsUnreadableAndKept() throws {
        try assertDamagedFileIsKept("{}")
    }

    func testNullLegacyKeyIsUnreadableAndKept() throws {
        try assertDamagedFileIsKept(#"{"queueIDs":null}"#)
    }

    func testWrongTypedLegacyKeyIsUnreadableAndKept() throws {
        try assertDamagedFileIsKept(#"{"queueIDs":"abc"}"#)
    }

    func testWrongTypedCurrentAssetIDIsUnreadableAndKept() throws {
        try assertDamagedFileIsKept(#"{"currentAssetID":5}"#)
    }

    func testEmptyLegacyKeysWithNothingToRestoreAreUnreadableAndKept() throws {
        try assertDamagedFileIsKept(#"{"queueIDs":[]}"#)
    }

    func testEmptyCurrentAssetIDWithNothingElseToRestoreIsUnreadableAndKept() throws {
        try assertDamagedFileIsKept(#"{"currentAssetID":"","queueIDs":[]}"#)
    }

    func testWhitespaceCurrentAssetIDWithNothingElseToRestoreIsUnreadableAndKept() throws {
        try assertDamagedFileIsKept(#"{"currentAssetID":"   ","queueIDs":[]}"#)
    }

    func testEmptyIdentifierInLegacyQueueIDsIsUnreadableAndKept() throws {
        try assertDamagedFileIsKept(#"{"queueIDs":[""]}"#)
    }

    func testWhitespaceIdentifierInALegacyIDArrayIsUnreadableAndKept() throws {
        try assertDamagedFileIsKept(#"{"decidedIDs":["  "],"keptIDs":["a"]}"#)
    }

    func testLegacyFileMigratesKeepsMarksAndLeavesABackup() async throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let legacy = #"{"currentAssetID":"c","queueIDs":["b"],"decidedIDs":["c"]}"#
        let url = try writeSessionFile(legacy, in: directory)
        let original = try Data(contentsOf: url)

        let store = FileSessionStore(directory: directory)
        guard case .migrated(let state) = store.loadState() else {
            return XCTFail("a real legacy file must still migrate, got \(store.loadState())")
        }
        XCTAssertEqual(state.marks, ["b"], "legacy queueIDs become the durable deletion list")
        XCTAssertEqual(state.session?.currentAssetID, "c")

        try await store.saveState(state)
        XCTAssertEqual(FileSessionStore(directory: directory).loadState(), .loaded(state))

        let backups = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasPrefix("session-premigration-") && $0.hasSuffix(".json") }
        let name = try XCTUnwrap(backups.first, "a pre-migration backup must be left next to the file")
        let backup = try Data(contentsOf: directory.appendingPathComponent(name))
        XCTAssertEqual(backup, original, "the backup must hold the original legacy bytes")
    }

    /// A real legacy file must still migrate, keep every kind of progress, write
    /// only after the upgrade succeeds, and leave a backup of the original bytes.
    private func assertLegacyFileMigratesAndLeavesABackup(
        _ json: String,
        file: StaticString = #filePath,
        line: UInt = #line,
        assertProgress: (PersistedState) -> Void = { _ in }
    ) async throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = try writeSessionFile(json, in: directory)
        let original = try Data(contentsOf: url)

        let store = FileSessionStore(directory: directory)
        let result = store.loadState()
        guard case .migrated(let state) = result else {
            return XCTFail("expected a migration, got \(result)", file: file, line: line)
        }
        assertProgress(state)

        try await store.saveState(state)
        XCTAssertEqual(
            FileSessionStore(directory: directory).loadState(),
            .loaded(state),
            file: file,
            line: line
        )

        let backups = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasPrefix("session-premigration-") && $0.hasSuffix(".json") }
        let name = try XCTUnwrap(
            backups.first,
            "a pre-migration backup must be left next to the file",
            file: file,
            line: line
        )
        let backup = try Data(contentsOf: directory.appendingPathComponent(name))
        XCTAssertEqual(
            backup,
            original,
            "the backup must hold the original legacy bytes",
            file: file,
            line: line
        )
    }

    func testLegacyFileWithOnlyKeptIDsIsUnreadableAndKept() throws {
        // keptIDs without a cursor or decided IDs is an inconsistent fragment:
        // the app cannot resume it, so migrating it would let the next session
        // silently replace it. Keep the bytes instead.
        try assertDamagedFileIsKept(#"{"keptIDs":["a"]}"#)
    }

    func testLegacyFileWithOnlyUndoEntriesIsUnreadableAndKept() throws {
        try assertDamagedFileIsKept(
            #"{"undoEntries":[{"assetID":"a","effect":{"kept":{}},"displacedAssetID":null}]}"#
        )
    }

    func testLegacyFileWithKeptIDsAndAResumableCursorKeepsTheKeptIDs() async throws {
        let legacy = #"{"currentAssetID":"c","keptIDs":["a","b"]}"#
        try await assertLegacyFileMigratesAndLeavesABackup(legacy) { state in
            XCTAssertEqual(state.session?.currentAssetID, "c")
            XCTAssertEqual(
                state.session?.keptIDs,
                ["a", "b"],
                "keptIDs are kept when the session is otherwise resumable"
            )
        }
    }

    func testLegacyFileWithOnlyAPendingTumblerPlanMigratesAndLeavesABackup() async throws {
        let legacy = #"{"tumbler":{"seed":7,"remaining":["a","b"],"handled":[]}}"#
        try await assertLegacyFileMigratesAndLeavesABackup(legacy) { state in
            XCTAssertEqual(
                state.session?.currentAssetID,
                "b",
                "a plan-only save seeds the cursor from the plan's own next identifier"
            )
            XCTAssertEqual(
                state.session?.tumbler?.remaining,
                ["a"],
                "the rest of the pending random order is preserved"
            )
            XCTAssertEqual(
                state.session?.mode,
                .tumbler,
                "a persisted Tumbler plan means a Random session, so the plan is not ignored"
            )
        }
    }

    /// The plan-only cursor must survive reconciliation. Without it, the
    /// reconciler would pick the newest photo chronologically and the engine
    /// would reserve that instead of the plan's next, reordering the walk.
    func testPlanOnlyTumblerMigrationKeepsThePlanOrderThroughReconciliation() throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        // `next()` pops the last entry, so "a" is the plan's intended first
        // photo; chronological reconciliation would choose the newest, "e".
        let legacy = #"{"tumbler":{"seed":7,"remaining":["e","a"],"handled":[]}}"#
        _ = try writeSessionFile(legacy, in: directory)

        let store = FileSessionStore(directory: directory)
        guard case .migrated(let migrated) = store.loadState() else {
            return XCTFail("expected a migration, got \(store.loadState())")
        }
        XCTAssertEqual(migrated.session?.currentAssetID, "a", "the cursor comes from the plan, not the clock")

        let order = TestLibrary.order()
        let reconciled = AssetReconciler.reconcile(migrated, order: order)
        XCTAssertEqual(
            reconciled.state.session?.currentAssetID,
            "a",
            "reconciliation must keep the plan's cursor, not pick the newest asset"
        )
        XCTAssertEqual(reconciled.state.session?.tumbler?.remaining, ["e"])

        let engine = SessionEngine.restored(from: try XCTUnwrap(reconciled.state.session), order: order)
        XCTAssertEqual(engine.current?.id, "a")
        XCTAssertEqual(engine.tumbler?.remaining, ["e"], "the rest of the random order survives")
    }

    /// A migration whose upgrade write keeps failing must reuse the backup it
    /// already made, not pile up a full copy on every launch.
    func testRepeatedMigrationAttemptsReuseTheExistingBackup() throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let legacy = #"{"currentAssetID":"c","queueIDs":["b"]}"#
        _ = try writeSessionFile(legacy, in: directory)

        // Each store reads the still-unmigrated file, as if the previous
        // migration write had failed and the next launch retried it.
        for _ in 0..<3 {
            let store = FileSessionStore(directory: directory)
            guard case .migrated = store.loadState() else {
                return XCTFail("expected a migration, got \(store.loadState())")
            }
        }

        let backups = try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasPrefix("session-premigration-") && $0.hasSuffix(".json") }
        XCTAssertEqual(backups.count, 1, "a retrying migration must reuse its backup")
        let backup = try Data(contentsOf: directory.appendingPathComponent(try XCTUnwrap(backups.first)))
        XCTAssertEqual(backup, Data(legacy.utf8), "the backup holds the original legacy bytes")
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

    /// Version 2 could record a favourite decision and version 3 removed
    /// favouriting, so a stored session may hold a favourite undo entry. It has
    /// to load, with that entry treated as a keep so undoing it only returns to
    /// the photo.
    func testVersionTwoSessionWithAFavouriteUndoEntryStillLoads() throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let versionTwo = #"""
        {"schemaVersion":2,"marks":[],"updatedAt":0,"session":{"currentAssetID":"b","direction":"older","mode":"sequential","decidedIDs":["a"],"keptIDs":["a"],"undoEntries":[{"assetID":"a","effect":{"favorited":{"previousValue":false}},"displacedAssetID":null}],"updatedAt":0,"isFinished":false}}
        """#
        try Data(versionTwo.utf8).write(to: directory.appendingPathComponent("session.json"))

        let store = FileSessionStore(directory: directory)
        guard case .migrated(let state) = store.loadState() else {
            return XCTFail("schema 2 should be migrated, got \(store.loadState())")
        }
        XCTAssertEqual(state.schemaVersion, PersistedState.currentSchemaVersion)
        XCTAssertEqual(state.session?.undoEntries.first?.effect, .kept)
        XCTAssertEqual(state.session?.currentAssetID, "b")
        XCTAssertEqual(state.session?.decidedIDs, ["a"])
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
            XCTAssertEqual(error as? SessionStoreError, .writeFailed("SWIPR is simulating a full disk."))
        }
        XCTAssertEqual(store.saveAttempts, 1)
        XCTAssertTrue(store.savedStates.isEmpty)
    }

    func testInMemoryStoreCanFailExactlyOneNumberOfedSaveAttempt() async throws {
        let store = InMemorySessionStore()
        store.failSaveAttempt = 2

        try await store.saveState(PersistedState(marks: ["a"]))
        do {
            try await store.saveState(PersistedState(marks: ["a", "b"]))
            XCTFail("attempt 2 should fail")
        } catch {
            XCTAssertEqual(error as? SessionStoreError, .writeFailed("SWIPR is simulating a full disk."))
        }
        try await store.saveState(PersistedState(marks: ["a", "b", "c"]))
        XCTAssertEqual(store.state?.marks, ["a", "b", "c"], "later attempts succeed again")
        XCTAssertEqual(store.saveAttempts, 3)
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

    func testInMemoryStoreReportsMigratedContent() async throws {
        let migrated = PersistedState(
            marks: ["b"],
            session: PersistedSession(currentAssetID: "c", filterCategories: [.screenshot], poolIDs: ["a", "c"])
        )
        let store = InMemorySessionStore(content: .migrated(migrated))
        XCTAssertEqual(store.loadState(), .migrated(migrated))
        XCTAssertEqual(store.state, migrated)
    }

    // MARK: - Filter and pool round trips

    func testPersistedSessionRoundTripsFilterAndPool() throws {
        let session = PersistedSession(
            currentAssetID: "c",
            direction: .older,
            filterCategories: [.screenshot, .video],
            poolIDs: ["a", "b", "c"]
        )
        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(PersistedSession.self, from: data)
        XCTAssertEqual(decoded, session)
        XCTAssertEqual(decoded.filterCategories, [.screenshot, .video])
        XCTAssertEqual(decoded.poolIDs, ["a", "b", "c"])
    }

    func testEngineRoundTripsFilterAndPool() {
        let poolOrder = LibraryOrder(TestLibrary.sequential().filter { ["b", "c", "e"].contains($0.id) })
        var engine = SessionEngine(
            order: poolOrder,
            direction: .older,
            poolIDs: ["b", "c", "e"],
            filterCategories: [.screenshot, .video]
        )
        engine.start()
        engine.apply(.keep)

        let persisted = engine.persisted()
        XCTAssertEqual(persisted.poolIDs, ["b", "c", "e"])
        XCTAssertEqual(persisted.filterCategories, [.screenshot, .video])

        let restored = SessionEngine.restored(from: persisted, order: TestLibrary.order(), marks: [])
        XCTAssertEqual(restored.order.ids, ["b", "c", "e"])
        XCTAssertEqual(restored.poolIDs, Set(["b", "c", "e"]))
        XCTAssertEqual(restored.filterCategories, [.screenshot, .video])
        XCTAssertEqual(restored.current?.id, engine.current?.id)
    }

    // MARK: - Schema 4 migration

    /// Version 3 had no pool or filter. Migrating it must keep every piece of
    /// acknowledged progress: position, marks, decisions and Undo.
    func testVersionThreeSessionMigratesToFourWithoutLoss() throws {
        let directory = makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let versionThree = #"""
        {"schemaVersion":3,"marks":["b"],"updatedAt":0,"session":{"currentAssetID":"d","currentAssetDate":0,"direction":"older","mode":"sequential","decidedIDs":["e","d"],"keptIDs":["e"],"undoEntries":[{"assetID":"e","effect":{"queuedDeletion":{}},"displacedAssetID":null}],"tumbler":null,"updatedAt":0,"isFinished":false}}
        """#
        try Data(versionThree.utf8).write(to: directory.appendingPathComponent("session.json"))

        let store = FileSessionStore(directory: directory)
        guard case .migrated(let state) = store.loadState() else {
            return XCTFail("schema 3 should be migrated, got \(store.loadState())")
        }
        XCTAssertEqual(state.schemaVersion, 4)
        XCTAssertEqual(state.marks, ["b"], "marks survive migration")
        XCTAssertEqual(state.session?.currentAssetID, "d", "position survives migration")
        XCTAssertEqual(state.session?.decidedIDs, ["e", "d"], "decisions survive migration")
        XCTAssertEqual(state.session?.keptIDs, ["e"])
        XCTAssertEqual(state.session?.undoEntries.first?.assetID, "e")
        XCTAssertEqual(state.session?.undoEntries.first?.effect, .queuedDeletion, "Undo survives migration")
        XCTAssertNil(state.session?.filterCategories, "a legacy session has no persisted filter")
        XCTAssertNil(state.session?.poolIDs, "a legacy session has no captured pool")
    }
}
