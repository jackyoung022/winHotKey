import SwiftUI
import AppKit

struct StatusMenuView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.permissionStatus != .authorized {
                Label("Grant Accessibility", systemImage: "exclamationmark.triangle")
                    .symbolVariant(.fill)
                    .foregroundStyle(.orange)
                Button("Open App") {
                    openMainWindow()
                }
            } else if viewModel.bindings.isEmpty {
                Text("No shortcuts configured")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.bindings) { binding in
                    Button {
                        viewModel.activate(binding: binding)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(bindingSummary(for: binding))
                                .font(.headline)
                            if let detail = bindingDetail(for: binding) {
                                Text(detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.borderless)
                }
            }
            Divider()
            Button("Open winHotKey") {
                openMainWindow()
            }
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(minWidth: 220)
    }

    private func openMainWindow() {
        MainWindowTracker.shared.showWindow()
    }

    private func bindingSummary(for binding: HotkeyBinding) -> String {
        "\(binding.hotKey.readable) — \(binding.window.ownerName)"
    }

    private func bindingDetail(for binding: HotkeyBinding) -> String? {
        guard !binding.window.title.isEmpty else {
            return nil
        }
        return binding.window.title
    }
}
