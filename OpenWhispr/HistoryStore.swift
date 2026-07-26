import Foundation
import NaturalLanguage

struct UsageStatistics: Codable, Equatable {
    static let minimumWordsForEffectiveWPM = 500

    private(set) var totalWords = 0
    private(set) var totalDurationSeconds: Double = 0

    var effectiveWordsPerMinute: Double? {
        guard totalWords >= Self.minimumWordsForEffectiveWPM,
              totalDurationSeconds > 0 else { return nil }
        return Double(totalWords) * 60 / totalDurationSeconds
    }

    mutating func record(text: String, durationSeconds: Double) {
        totalWords += Self.wordCount(in: text)
        totalDurationSeconds += max(0, durationSeconds)
    }

    private static func wordCount(in text: String) -> Int {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var count = 0
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { _, _ in
            count += 1
            return true
        }
        return count
    }
}

struct DictationEntry: Codable, Identifiable {
    let id: UUID
    let text: String
    let date: Date
    let durationSeconds: Double

    init(text: String, durationSeconds: Double) {
        self.id = UUID()
        self.text = text
        self.date = Date()
        self.durationSeconds = durationSeconds
    }
}

class HistoryStore: ObservableObject {
    @Published var entries: [DictationEntry] = []
    @Published private(set) var usageStatistics = UsageStatistics()

    private let storageDirectory: URL
    private var fileURL: URL { storageDirectory.appendingPathComponent("history.json") }
    private var usageFileURL: URL { storageDirectory.appendingPathComponent("usage.json") }

    init(storageDirectory: URL? = nil) {
        self.storageDirectory = storageDirectory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("OpenWhispr")
        try? FileManager.default.createDirectory(
            at: self.storageDirectory,
            withIntermediateDirectories: true
        )
        load()
        loadUsage()
    }

    func add(text: String, durationSeconds: Double) {
        let entry = DictationEntry(text: text, durationSeconds: durationSeconds)
        entries.insert(entry, at: 0)
        usageStatistics.record(text: text, durationSeconds: durationSeconds)
        saveUsage()
        // Keep last 500
        if entries.count > 500 {
            entries = Array(entries.prefix(500))
        }
        save()
    }

    func clear() {
        entries = []
        save()
    }

    func delete(_ entry: DictationEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            entries = try JSONDecoder().decode([DictationEntry].self, from: data)
        } catch {
            print("Failed to load history: \(error)")
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: fileURL)
        } catch {
            print("Failed to save history: \(error)")
        }
    }

    private func loadUsage() {
        guard FileManager.default.fileExists(atPath: usageFileURL.path) else {
            for entry in entries {
                usageStatistics.record(
                    text: entry.text,
                    durationSeconds: entry.durationSeconds
                )
            }
            saveUsage()
            return
        }
        do {
            let data = try Data(contentsOf: usageFileURL)
            usageStatistics = try JSONDecoder().decode(UsageStatistics.self, from: data)
        } catch {
            print("Failed to load usage statistics: \(error)")
        }
    }

    private func saveUsage() {
        do {
            let data = try JSONEncoder().encode(usageStatistics)
            try data.write(to: usageFileURL, options: .atomic)
        } catch {
            print("Failed to save usage statistics: \(error)")
        }
    }
}
