import AppKit
import SwiftUI

final class MainWindowTracker {
    static let shared = MainWindowTracker()

    private weak var window: NSWindow?
    private var closeObserver: NSObjectProtocol?
    private weak var viewModel: AppViewModel?

    private init() {}

    func configure(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    func register(window: NSWindow) {
        guard self.window !== window else { return }
        self.window = window
        window.identifier = NSUserInterfaceItemIdentifier("winHotKey.mainWindow")

        if let closeObserver {
            NotificationCenter.default.removeObserver(closeObserver)
        }

        closeObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification,
                                                               object: window,
                                                               queue: .main) { [weak self] notification in
            guard
                let self,
                let closingWindow = notification.object as? NSWindow,
                closingWindow == self.window
            else { return }
            self.window = nil
        }
    }

    func showWindow() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        } else if let window = createWindow() {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        }
    }

    deinit {
        if let closeObserver {
            NotificationCenter.default.removeObserver(closeObserver)
        }
    }

    private func createWindow() -> NSWindow? {
        if let window {
            return window
        }

        if let viewModel {
            let controller = NSHostingController(rootView: ContentView().environmentObject(viewModel))
            let window = NSWindow(contentViewController: controller)
            window.title = "winHotKey"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 760, height: 560))
            window.center()
            register(window: window)
            return window
        }

        return nil
    }
}
