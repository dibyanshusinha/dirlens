import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppState: ObservableObject {
    @Published var imageURLs: [URL] = []
    @Published var currentIndex: Int = 0
    @Published var zoomScale: CGFloat = 1.0
    @Published var rotationDegrees: Double = 0
    @Published var isDrawerVisible: Bool = false
    @Published var currentNSImage: NSImage?
    @Published var isLoading: Bool = false
    @Published var isRotating: Bool = false
    @Published var errorMessage: String?
    @Published var pendingDeleteURL: URL?
    @Published var thumbnailRefreshTick: Int = 0

    private static let minZoom: CGFloat = 0.2
    private static let maxZoom: CGFloat = 8.0

    var currentURL: URL? {
        guard imageURLs.indices.contains(currentIndex) else { return nil }
        return imageURLs[currentIndex]
    }

    var canNavigate: Bool { imageURLs.count > 1 }

    func open(url: URL) {
        errorMessage = nil
        imageURLs = FileScanner.imageURLs(inFolderOf: url)
        currentIndex = imageURLs.firstIndex(of: url) ?? 0
        resetTransform()
        loadCurrentImage()
    }

    func openPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            open(url: url)
        }
    }

    func jump(to index: Int) {
        guard imageURLs.indices.contains(index), index != currentIndex else { return }
        currentIndex = index
        resetTransform()
        loadCurrentImage()
    }

    func next() {
        guard !imageURLs.isEmpty else { return }
        currentIndex = (currentIndex + 1) % imageURLs.count
        resetTransform()
        loadCurrentImage()
    }

    func previous() {
        guard !imageURLs.isEmpty else { return }
        currentIndex = (currentIndex - 1 + imageURLs.count) % imageURLs.count
        resetTransform()
        loadCurrentImage()
    }

    func resetTransform() {
        withAnimation(.easeInOut(duration: 0.15)) {
            zoomScale = 1.0
            rotationDegrees = 0
        }
    }

    func zoomIn() {
        withAnimation(.easeInOut(duration: 0.15)) {
            zoomScale = min(Self.maxZoom, zoomScale * 1.25)
        }
    }

    func zoomOut() {
        withAnimation(.easeInOut(duration: 0.15)) {
            zoomScale = max(Self.minZoom, zoomScale / 1.25)
        }
    }

    func rotateLeft() {
        rotate(byDegrees: -90)
    }

    func rotateRight() {
        rotate(byDegrees: 90)
    }

    /// Rotates the current image both on screen (immediately, for responsiveness)
    /// and on disk (in the background) so the file itself ends up rotated, not
    /// just this session's view of it.
    private func rotate(byDegrees delta: Int) {
        guard let url = currentURL else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            rotationDegrees += Double(delta)
        }
        isRotating = true

        let targetIndex = currentIndex
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let success = ImageRotator.rotate(fileAt: url, byDegrees: delta)
            DispatchQueue.main.async {
                guard let self else { return }
                self.isRotating = false
                guard self.currentIndex == targetIndex else { return }

                if success {
                    ThumbnailCache.shared.invalidate(url)
                    self.thumbnailRefreshTick += 1
                    self.rotationDegrees = 0
                    self.loadCurrentImage()
                } else {
                    self.errorMessage = "Couldn't rotate \(url.lastPathComponent)"
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.rotationDegrees -= Double(delta)
                    }
                }
            }
        }
    }

    func editInPreview() {
        guard let url = currentURL else { return }
        guard let previewURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Preview") else {
            errorMessage = "Preview isn't available on this Mac"
            return
        }
        NSWorkspace.shared.open([url], withApplicationAt: previewURL, configuration: NSWorkspace.OpenConfiguration()) { [weak self] _, error in
            guard let error else { return }
            DispatchQueue.main.async {
                self?.errorMessage = "Couldn't open in Preview: \(error.localizedDescription)"
            }
        }
    }

    func toggleDrawer() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isDrawerVisible.toggle()
        }
    }

    func requestDelete() {
        guard let url = currentURL else { return }
        pendingDeleteURL = url
    }

    func cancelDelete() {
        pendingDeleteURL = nil
    }

    func confirmDelete() {
        guard let url = pendingDeleteURL else { return }
        pendingDeleteURL = nil

        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        } catch {
            errorMessage = "Couldn't move \(url.lastPathComponent) to Trash"
            return
        }

        guard let removedIndex = imageURLs.firstIndex(of: url) else { return }
        imageURLs.remove(at: removedIndex)
        if imageURLs.isEmpty {
            currentIndex = 0
            currentNSImage = nil
        } else {
            currentIndex = min(removedIndex, imageURLs.count - 1)
            resetTransform()
            loadCurrentImage()
        }
    }

    private func loadCurrentImage() {
        guard let url = currentURL else {
            currentNSImage = nil
            return
        }
        isLoading = true
        let targetIndex = currentIndex
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let image = NSImage(contentsOf: url)
            DispatchQueue.main.async {
                guard let self, self.currentIndex == targetIndex else { return }
                self.currentNSImage = image
                self.isLoading = false
                if image == nil {
                    self.errorMessage = "Couldn't load \(url.lastPathComponent)"
                }
            }
        }
    }
}
