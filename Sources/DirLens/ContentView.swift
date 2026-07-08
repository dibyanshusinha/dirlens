import SwiftUI

struct ContentView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            ImageCanvasView(state: state)
                .frame(minWidth: 500, minHeight: 400)

            if state.isDrawerVisible {
                Divider()
                ThumbnailDrawerView(state: state)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button(action: { state.openPanel() }) {
                    Image(systemName: "folder")
                }
                .help("Open Image… (⌘O)")
            }

            ToolbarItemGroup {
                Button(action: { state.previous() }) {
                    Image(systemName: "chevron.left")
                }
                .keyboardShortcut(.leftArrow, modifiers: [])
                .disabled(!state.canNavigate)
                .help("Previous Image (←)")

                Button(action: { state.next() }) {
                    Image(systemName: "chevron.right")
                }
                .keyboardShortcut(.rightArrow, modifiers: [])
                .disabled(!state.canNavigate)
                .help("Next Image (→)")

                Divider()

                Button(action: { state.zoomOut() }) {
                    Image(systemName: "minus.magnifyingglass")
                }
                .keyboardShortcut("-", modifiers: .command)
                .help("Zoom Out (⌘-)")

                Button(action: { state.resetTransform() }) {
                    Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
                }
                .keyboardShortcut("0", modifiers: .command)
                .help("Reset Zoom (⌘0)")

                Button(action: { state.zoomIn() }) {
                    Image(systemName: "plus.magnifyingglass")
                }
                .keyboardShortcut("=", modifiers: .command)
                .help("Zoom In (⌘+)")

                Divider()

                Button(action: { state.rotateLeft() }) {
                    Image(systemName: "rotate.left")
                }
                .keyboardShortcut("[", modifiers: .command)
                .help("Rotate Left (⌘[)")

                Button(action: { state.rotateRight() }) {
                    Image(systemName: "rotate.right")
                }
                .keyboardShortcut("]", modifiers: .command)
                .help("Rotate Right (⌘])")

                Divider()

                Button(action: { state.toggleDrawer() }) {
                    Image(systemName: "square.grid.3x1.below.line.grid.1x2")
                }
                .keyboardShortcut(.space, modifiers: [])
                .help("Toggle Thumbnails (Space)")
            }
        }
        .navigationTitle(state.currentURL?.lastPathComponent ?? "DirLens")
        .navigationSubtitle(state.imageURLs.isEmpty ? "" : "\(state.currentIndex + 1) of \(state.imageURLs.count)")
    }
}
