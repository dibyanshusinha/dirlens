import SwiftUI
import UniformTypeIdentifiers

struct ImageCanvasView: View {
    @ObservedObject var state: AppState

    @State private var dragOffset: CGSize = .zero
    @GestureState private var magnifyBy: CGFloat = 1.0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let nsImage = state.currentNSImage {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .rotationEffect(.degrees(state.rotationDegrees))
                        .scaleEffect(state.zoomScale * magnifyBy)
                        .offset(dragOffset)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .contentShape(Rectangle())
                        .gesture(
                            MagnificationGesture()
                                .updating($magnifyBy) { value, gestureState, _ in
                                    gestureState = value
                                }
                                .onEnded { value in
                                    state.zoomScale = max(0.2, min(8.0, state.zoomScale * value))
                                }
                        )
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    guard state.zoomScale > 1.0 else { return }
                                    dragOffset = value.translation
                                }
                                .onEnded { _ in
                                    if state.zoomScale <= 1.0 {
                                        dragOffset = .zero
                                    }
                                }
                        )
                        .onTapGesture(count: 2) {
                            dragOffset = .zero
                            state.resetTransform()
                        }
                } else if state.isLoading {
                    ProgressView()
                } else {
                    emptyState
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .clipped()
        .onChange(of: state.currentIndex) { _, _ in
            dragOffset = .zero
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Open an image or drop it here")
                .foregroundStyle(.secondary)
            Button("Open Image…") { state.openPanel() }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url else { return }
            DispatchQueue.main.async {
                state.open(url: url)
            }
        }
        return true
    }
}
