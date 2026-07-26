import XCTest
@testable import OpenWhispr

final class HistoryStoreUsageStatisticsTests: XCTestCase {
    private var storageDirectory: URL!

    override func setUp() {
        super.setUp()
        storageDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: storageDirectory)
        storageDirectory = nil
        super.tearDown()
    }

    func testAddingDictationUpdatesLifetimeTotals() {
        let store = HistoryStore(storageDirectory: storageDirectory)

        store.add(text: "One two, three.", durationSeconds: 30)

        XCTAssertEqual(store.usageStatistics.totalWords, 3)
        XCTAssertEqual(store.usageStatistics.totalDurationSeconds, 30)
    }

    func testLifetimeTotalsPersistAcrossStoreReloads() {
        HistoryStore(storageDirectory: storageDirectory)
            .add(text: "A persisted dictation", durationSeconds: 12)

        let reloadedStore = HistoryStore(storageDirectory: storageDirectory)

        XCTAssertEqual(reloadedStore.usageStatistics.totalWords, 3)
        XCTAssertEqual(reloadedStore.usageStatistics.totalDurationSeconds, 12)
    }

    func testEffectiveWPMBecomesAvailableAfterFiveHundredWords() {
        let store = HistoryStore(storageDirectory: storageDirectory)

        store.add(
            text: String(repeating: "word ", count: 499),
            durationSeconds: 299.4
        )
        XCTAssertNil(store.usageStatistics.effectiveWordsPerMinute)

        store.add(text: "word", durationSeconds: 0.6)

        XCTAssertEqual(store.usageStatistics.effectiveWordsPerMinute, 100)
    }

    func testExistingHistorySeedsLifetimeTotalsWhenUsageFileIsMissing() throws {
        HistoryStore(storageDirectory: storageDirectory)
            .add(text: "Existing history entry", durationSeconds: 15)
        try FileManager.default.removeItem(
            at: storageDirectory.appendingPathComponent("usage.json")
        )

        let migratedStore = HistoryStore(storageDirectory: storageDirectory)

        XCTAssertEqual(migratedStore.usageStatistics.totalWords, 3)
        XCTAssertEqual(migratedStore.usageStatistics.totalDurationSeconds, 15)
    }

    func testWordCountIgnoresStandalonePunctuation() {
        let store = HistoryStore(storageDirectory: storageDirectory)

        store.add(text: "Hello, world! …", durationSeconds: 2)

        XCTAssertEqual(store.usageStatistics.totalWords, 2)
    }

    func testClearingHistoryDoesNotClearLifetimeTotals() {
        let store = HistoryStore(storageDirectory: storageDirectory)
        store.add(text: "Keep these lifetime words", durationSeconds: 4)

        store.clear()
        let reloadedStore = HistoryStore(storageDirectory: storageDirectory)

        XCTAssertTrue(reloadedStore.entries.isEmpty)
        XCTAssertEqual(reloadedStore.usageStatistics.totalWords, 4)
        XCTAssertEqual(reloadedStore.usageStatistics.totalDurationSeconds, 4)
    }
}
