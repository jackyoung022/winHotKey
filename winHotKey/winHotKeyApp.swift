import SwiftUI

@main
struct winHotKeyApp: App {
    @StateObject private var viewModel: AppViewModel

    init() {
        let viewModel = AppViewModel()
        _viewModel = StateObject(wrappedValue: viewModel)
        MainWindowTracker.shared.configure(viewModel: viewModel)
        DispatchQueue.main.async {
            MainWindowTracker.shared.showWindow()
        }
    }

    var body: some Scene {
        MenuBarExtra("winHotKey", systemImage: "bolt.circle") {
            StatusMenuView()
                .environmentObject(viewModel)
        }
    }
}
