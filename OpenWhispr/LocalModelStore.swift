import Foundation

struct LocalModelStore {
    private let downloadBase: URL
    private let fileManager: FileManager

    init(
        downloadBase: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.downloadBase = downloadBase
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("huggingface", isDirectory: true)
    }

    func modelFolder(for variant: String) -> URL {
        downloadBase
            .appendingPathComponent("models", isDirectory: true)
            .appendingPathComponent("argmaxinc", isDirectory: true)
            .appendingPathComponent("whisperkit-coreml", isDirectory: true)
            .appendingPathComponent(variant, isDirectory: true)
    }

    func downloadedModelFolder(for variant: String) -> URL? {
        let folder = modelFolder(for: variant)
        let requiredItems = [
            "config.json",
            "AudioEncoder.mlmodelc",
            "MelSpectrogram.mlmodelc",
            "TextDecoder.mlmodelc",
        ]

        guard requiredItems.allSatisfy({
            fileManager.fileExists(
                atPath: folder.appendingPathComponent($0).path
            )
        }) else {
            return nil
        }

        return folder
    }
}
