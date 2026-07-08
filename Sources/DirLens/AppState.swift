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
    @Published var errorMessage: String?

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
        withAnimation(.easeInOut(duration: 0.2)) {
            rotationDegrees -= 90
        }
    }

    func rotateRight() {
        withAnimation(.easeInOut(duration: 0.2)) {
            rotationDegrees += 90
        }
    }

    func toggleDrawer() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isDrawerVisible.toggle()
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
