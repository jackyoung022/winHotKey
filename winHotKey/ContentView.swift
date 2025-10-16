import SwiftUI
import AppKit

struct AlertMessage: Identifiable {
    let id = UUID()
    let message: String
}

struct ContentView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var selectedWindow: WindowInfo?
    @State private var recordedHotkey: HotKeyDescriptor?
    @State private var alertMessage: AlertMessage?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                Divider()
                if viewModel.permissionStatus != .authorized {
                    permissionPrompt
                } else {
                    quickBindingPanel
                        .padding(.bottom, 8)
                    configurationPanel
                    Divider()
                    bindingsList
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 720, minHeight: 560)
        .background(WindowReader { window in
            MainWindowTracker.shared.register(window: window)
        })
        .onAppear {
            viewModel.refreshWindows()
            DispatchQueue.main.async {
                if let pending = viewModel.pendingWindowSelection {
                    handlePendingSelection(pending)
                }
            }
        }
        .onReceive(viewModel.$pendingWindowSelection) { pending in
            guard let pending else { return }
            DispatchQueue.main.async {
                handlePendingSelection(pending)
            }
        }
        .alert(item: $alertMessage) { message in
            Alert(title: Text("Attention"), message: Text(message.message), dismissButton: .default(Text("OK")))
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("winHotKey")
                    .font(.title2)
                    .bold()
                Text("Assign global shortcuts to bring application windows to front")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: viewModel.refreshWindows) {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .help("Refresh the list of visible windows")
        }
    }

    private var permissionPrompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Accessibility access required", systemImage: "exclamationmark.triangle")
                .font(.headline)
            Text("winHotKey needs Accessibility permissions to monitor and activate other application windows. Grant access in System Settings → Privacy & Security → Accessibility, then return to this app.")
                .fixedSize(horizontal: false, vertical: true)
            Button("Open System Settings") {
                viewModel.requestAccessibility()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var quickBindingPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Capture Shortcut")
                .font(.headline)

            ViewThatFits(in: .horizontal) {
                quickBindingControls(horizontal: true)
                quickBindingControls(horizontal: false)
            }

            Text("Use this shortcut to open winHotKey with the active window preselected. You can reset or disable it here at any time.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var configurationPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Create Shortcut")
                .font(.headline)

            ViewThatFits(in: .horizontal) {
                configurationInputs(horizontal: true)
                configurationInputs(horizontal: false)
            }
        }
    }

    private var bindingsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Registered Shortcuts")
                .font(.headline)
            if viewModel.bindings.isEmpty {
                Text("No shortcuts yet. Create one above to get started.")
                    .foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(viewModel.bindings) { binding in
                        bindingRow(for: binding)
                    }
                    .onDelete(perform: deleteBindings)
                }
                .listStyle(.inset)
                .frame(minHeight: 240)
            }
        }
    }

    private func bindingRow(for binding: HotkeyBinding) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(binding.hotKey.readable)
                    .font(.headline)
                    .monospaced()
                Spacer()
                Toggle("Enabled", isOn: bindingToggle(binding))
                    .toggleStyle(SwitchToggleStyle())
                    .labelsHidden()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(binding.window.ownerName)
                    .font(.subheadline)
                if !binding.window.title.isEmpty {
                    Text(binding.window.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                Button {
                    viewModel.activate(binding: binding)
                } label: {
                    Label("Test", systemImage: "play.circle")
                }
                Button(role: .destructive) {
                    viewModel.removeBinding(binding)
                } label: {
                    Label("Remove", systemImage: "trash")
                }
                .buttonStyle(.borderless)
                Spacer()
            }
        }
        .padding(.vertical, 8)
    }

    private func bindingToggle(_ binding: HotkeyBinding) -> Binding<Bool> {
        guard let index = viewModel.bindings.firstIndex(of: binding) else {
            return .constant(binding.isEnabled)
        }
        return Binding {
            viewModel.bindings[index].isEnabled
        } set: { newValue in
            viewModel.setBinding(viewModel.bindings[index], isEnabled: newValue)
        }
    }

    private func deleteBindings(at offsets: IndexSet) {
        viewModel.bindings.remove(atOffsets: offsets)
    }

    private func addBinding() {
        guard let window = selectedWindow, let hotKey = recordedHotkey else {
            return
        }
        if let conflict = viewModel.bindings.first(where: { $0.hotKey == hotKey }) {
            let description = "Shortcut \(hotKey.readable) is already bound to \(conflict.window.displayName). Remove or change the existing binding first."
            alertMessage = AlertMessage(message: description)
            return
        }
        if let quickHotKey = viewModel.quickBindingHotKey, quickHotKey == hotKey {
            let description = "Shortcut \(hotKey.readable) is reserved for the Quick Capture action. Choose a different combination or update the Quick Capture shortcut first."
            alertMessage = AlertMessage(message: description)
            return
        }
        viewModel.addBinding(window: window, hotKey: hotKey)
        recordedHotkey = nil
        selectedWindow = nil
    }

    @ViewBuilder
    private func quickBindingControls(horizontal: Bool) -> some View {
        let recorder = HotkeyRecorderView(hotKey: quickBindingHotKeyBinding)
            .frame(minWidth: 160, idealWidth: 200, maxWidth: 220, minHeight: 24)

        let summary = Text(viewModel.quickBindingHotKey?.readable ?? "Disabled")
            .font(.body.monospaced())
            .foregroundStyle(viewModel.quickBindingHotKey == nil ? .secondary : .primary)
            .lineLimit(1)

        let buttons = HStack(spacing: 12) {
            Button("Reset") {
                if let message = viewModel.updateQuickBindingHotKey(AppViewModel.defaultQuickBindingHotKey) {
                    alertMessage = AlertMessage(message: message)
                }
            }
            .disabled(viewModel.quickBindingHotKey == AppViewModel.defaultQuickBindingHotKey)

            Button("Disable") {
                if let message = viewModel.updateQuickBindingHotKey(nil) {
                    alertMessage = AlertMessage(message: message)
                }
            }
            .disabled(viewModel.quickBindingHotKey == nil)
        }

        if horizontal {
            HStack(alignment: .center, spacing: 16) {
                recorder
                summary
                Spacer(minLength: 16)
                buttons
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                recorder
                summary
                buttons
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func configurationInputs(horizontal: Bool) -> some View {
        let targetPicker = VStack(alignment: .leading, spacing: 6) {
            Text("Target window")
                .font(.subheadline)
            Picker("Window", selection: $selectedWindow) {
                Text("Choose window").tag(WindowInfo?.none)
                ForEach(viewModel.availableWindows) { window in
                    Text(window.displayName)
                        .tag(Optional(window))
                }
            }
            .labelsHidden()
        }

        let shortcutSection = VStack(alignment: .leading, spacing: 6) {
            Text("Shortcut")
                .font(.subheadline)
            HotkeyRecorderView(hotKey: $recordedHotkey)
                .frame(minWidth: 150, idealWidth: 180, maxWidth: 200, minHeight: 24)
        }

        let previewSection = VStack(alignment: .leading, spacing: 6) {
            Text("Preview")
                .font(.subheadline)
            Text(recordedHotkey?.readable ?? "—")
                .font(.body.monospaced())
                .padding(.vertical, 3)
                .padding(.horizontal, 10)
                .background(Color(nsColor: .windowBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }

        let addButton = Button("Add Binding") {
            addBinding()
        }
        .disabled(selectedWindow == nil || recordedHotkey == nil)

        if horizontal {
            HStack(alignment: .top, spacing: 16) {
                targetPicker
                    .frame(maxWidth: 300, alignment: .leading)
                shortcutSection
                previewSection
                Spacer(minLength: 16)
                addButton
            }
        } else {
            VStack(alignment: .leading, spacing: 16) {
                targetPicker
                    .frame(maxWidth: .infinity, alignment: .leading)
                shortcutSection
                    .frame(maxWidth: .infinity, alignment: .leading)
                previewSection
                    .frame(maxWidth: .infinity, alignment: .leading)
                addButton
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func handlePendingSelection(_ pending: WindowInfo) {
        recordedHotkey = nil
        if let match = viewModel.availableWindows.first(where: { $0.windowNumber == pending.windowNumber }) {
            selectedWindow = match
        } else {
            if selectedWindow != nil {
                selectedWindow = nil
            }
            alertMessage = AlertMessage(message: "Could not locate the captured window. Try bringing it to the front and refreshing.")
        }
        viewModel.clearPendingWindowSelection()
    }

    private var quickBindingHotKeyBinding: Binding<HotKeyDescriptor?> {
        Binding {
            viewModel.quickBindingHotKey
        } set: { newValue in
            if let message = viewModel.updateQuickBindingHotKey(newValue) {
                alertMessage = AlertMessage(message: message)
            }
        }
    }
}

private struct WindowReader: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = ResolverView()
        view.onResolve = onResolve
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    final class ResolverView: NSView {
        var onResolve: ((NSWindow) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            onResolve?(window)
        }
    }
}
