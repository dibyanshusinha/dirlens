import AppKit
import SwiftUI

@main
struct DirLensApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView(state: state)
                .frame(minWidth: 640, minHeight: 480)
                .onAppear {
                    appDelegate.state = state
                    if let path = CommandLine.arguments.dropFirst().first {
                        state.open(url: URL(fileURLWithPath: path))
                    }
                }
        }
        .defaultSize(width: 1000, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open…") { state.openPanel() }
                    .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var state: AppState?

    func application(_ sender: NSApplication, open urls: [URL]) {
        guard let first = urls.first else { return }
        state?.open(url: first)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
