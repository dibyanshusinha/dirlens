import SwiftUI

struct ThumbnailDrawerView: View {
    @ObservedObject var state: AppState

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(Array(state.imageURLs.enumerated()), id: \.offset) { index, url in
                        ThumbnailCell(url: url, isSelected: index == state.currentIndex)
                            .id(index)
                            .onTapGesture { state.jump(to: index) }
                    }
                }
                .padding(10)
            }
            .onAppear {
                proxy.scrollTo(state.currentIndex, anchor: .center)
            }
            .onChange(of: state.currentIndex) { _, newValue in
                withAnimation {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
        .frame(height: 116)
        .background(.regularMaterial)
    }
}

private struct ThumbnailCell: View {
    let url: URL
    let isSelected: Bool
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.2))
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 92, height: 92)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .frame(width: 92, height: 92)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
        )
        .shadow(color: .black.opacity(isSelected ? 0.25 : 0), radius: 4)
        .task(id: url) {
            image = await ThumbnailCache.shared.thumbnail(for: url)
        }
    }
}
