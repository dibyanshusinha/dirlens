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
                .disabled(state.currentURL == nil || state.isRotating)
                .help("Rotate Left — saves to the file (⌘[)")

                Button(action: { state.rotateRight() }) {
                    Image(systemName: "rotate.right")
                }
                .keyboardShortcut("]", modifiers: .command)
                .disabled(state.currentURL == nil || state.isRotating)
                .help("Rotate Right — saves to the file (⌘])")

                Divider()

                Button(action: { state.editInPreview() }) {
                    Image(systemName: "pencil")
                }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(state.currentURL == nil)
                .help("Edit in Preview (⌘E)")

                Divider()

                Button(action: { state.toggleDrawer() }) {
                    Image(systemName: "square.grid.3x1.below.line.grid.1x2")
                }
                .keyboardShortcut(.space, modifiers: [])
                .help("Toggle Thumbnails (Space)")

                Divider()

                Button(role: .destructive, action: { state.requestDelete() }) {
                    Image(systemName: "trash")
                }
                .keyboardShortcut(.delete, modifiers: .command)
                .disabled(state.currentURL == nil)
                .help("Move to Trash (⌘⌫)")
            }
        }
        .navigationTitle(state.currentURL?.lastPathComponent ?? "DirLens")
        .navigationSubtitle(state.imageURLs.isEmpty ? "" : "\(state.currentIndex + 1) of \(state.imageURLs.count)")
        .alert(
            "Move “\(state.pendingDeleteURL?.lastPathComponent ?? "")” to Trash?",
            isPresented: Binding(
                get: { state.pendingDeleteURL != nil },
                set: { if !$0 { state.cancelDelete() } }
            )
        ) {
            Button("Cancel", role: .cancel) { state.cancelDelete() }
            Button("Move to Trash", role: .destructive) { state.confirmDelete() }
        }
    }
}
