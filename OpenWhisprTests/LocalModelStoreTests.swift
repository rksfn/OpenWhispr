import Foundation
import XCTest
@testable import OpenWhispr

final class LocalModelStoreTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testFindsCompleteDownloadedModel() throws {
        let store = LocalModelStore(downloadBase: temporaryDirectory)
        let modelFolder = store.modelFolder(for: "openai_whisper-small")

        try createCompleteModel(at: modelFolder)

        XCTAssertEqual(
            store.downloadedModelFolder(for: "openai_whisper-small"),
            modelFolder
        )
    }

    func testRejectsIncompleteDownloadedModel() throws {
        let store = LocalModelStore(downloadBase: temporaryDirectory)
        let modelFolder = store.modelFolder(for: "openai_whisper-small")

        try FileManager.default.createDirectory(
            at: modelFolder.appendingPathComponent("AudioEncoder.mlmodelc"),
            withIntermediateDirectories: true
        )
        try Data("{}".utf8).write(
            to: modelFolder.appendingPathComponent("config.json")
        )

        XCTAssertNil(store.downloadedModelFolder(for: "openai_whisper-small"))
    }

    private func createCompleteModel(at modelFolder: URL) throws {
        try FileManager.default.createDirectory(
            at: modelFolder,
            withIntermediateDirectories: true
        )
        try Data("{}".utf8).write(
            to: modelFolder.appendingPathComponent("config.json")
        )
        for component in [
            "AudioEncoder.mlmodelc",
            "MelSpectrogram.mlmodelc",
            "TextDecoder.mlmodelc",
        ] {
            try FileManager.default.createDirectory(
                at: modelFolder.appendingPathComponent(component),
                withIntermediateDirectories: true
            )
        }
    }
}
