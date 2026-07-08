import Foundation

enum FileScanner {
    static let supportedExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "heic", "heif", "webp"
    ]

    /// Finds all supported images in the same folder as `fileURL`, naturally sorted by name.
    static func imageURLs(inFolderOf fileURL: URL) -> [URL] {
        let folder = fileURL.deletingLastPathComponent()
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return [fileURL]
        }

        let images = contents.filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
        let sorted = images.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
        return sorted.isEmpty ? [fileURL] : sorted
    }
}
