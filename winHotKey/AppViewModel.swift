import AppKit
import Carbon
import Combine

@MainActor
final class AppViewModel: ObservableObject {
    @Published var permissionStatus: AccessibilityStatus = .unknown
    @Published var availableWindows: [WindowInfo] = []
    @Published var bindings: [HotkeyBinding] = [] {
        didSet {
            saveBindings()
            registerBindings()
        }
    }
    @Published var isRecordingHotkey = false
    @Published var pendingWindowSelection: WindowInfo?
    @Published private(set) var quickBindingHotKey: HotKeyDescriptor?

    private let accessibilityManager = AccessibilityPermissionManager.shared
    private let windowService = WindowService.shared
    private let storageKey = "hotkey_bindings"
    private let setupHotKeyIdentifier = "quick_binding_setup"
    private static let quickHotKeyStorageKey = "quick_binding_hotkey"
    static let defaultQuickBindingHotKey = HotKeyDescriptor(
        keyCode: UInt32(kVK_ANSI_S),
        modifiers: UInt32(cmdKey | optionKey)
    )

    init() {
        quickBindingHotKey = Self.loadQuickBindingHotKey()
        if quickBindingHotKey == nil {
            quickBindingHotKey = Self.defaultQuickBindingHotKey
            saveQuickBindingHotKey(Self.defaultQuickBindingHotKey)
        }

        HotKeyManager.shared.clearAll()
        if let error = registerSetupHotKey() {
            NSLog("%@", error)
        }
        bind()
        loadBindings()
    }

    func bind() {
        accessibilityManager.$status
            .receive(on: RunLoop.main)
            .assign(to: &self.$permissionStatus)

        windowService.$windows
            .receive(on: RunLoop.main)
            .assign(to: &self.$availableWindows)
    }

    func requestAccessibility() {
        let result = accessibilityManager.requestAccess()
        switch result {
        case .granted:
            permissionStatus = .authorized
        case .requiresManual, .denied:
            permissionStatus = accessibilityManager.status
        }
    }

    func refreshWindows() {
        windowService.refreshWindows()
    }

    func addBinding(window: WindowInfo, hotKey: HotKeyDescriptor) {
        var updated = bindings.filter { $0.hotKey != hotKey }
        let binding = HotkeyBinding(hotKey: hotKey, window: window)
        updated.append(binding)
        bindings = updated
    }

    func removeBinding(_ binding: HotkeyBinding) {
        if let index = bindings.firstIndex(of: binding) {
            bindings.remove(at: index)
        }
    }

    func toggleBinding(_ binding: HotkeyBinding) {
        setBinding(binding, isEnabled: !binding.isEnabled)
    }

    func setBinding(_ binding: HotkeyBinding, isEnabled: Bool) {
        guard let index = bindings.firstIndex(of: binding) else { return }
        var updated = bindings
        updated[index].isEnabled = isEnabled
        bindings = updated
    }

    func activate(binding: HotkeyBinding) {
        guard let target = resolveWindow(for: binding) else {
            return
        }
        WindowActivator.activate(window: target)
    }

    private func resolveWindow(for binding: HotkeyBinding) -> WindowInfo? {
        if let match = availableWindows.first(where: { $0.windowNumber == binding.window.windowNumber }) {
            return match
        }
        if let match = availableWindows.first(where: { candidate in
            candidate.bundleIdentifier == binding.window.bundleIdentifier &&
            candidate.title == binding.window.title
        }) {
            return match
        }
        return nil
    }

    private func registerBindings() {
        HotKeyManager.shared.clearBindings()
        for binding in bindings where binding.isEnabled {
            HotKeyManager.shared.register(binding: binding) { [weak self] in
                Task { @MainActor in
                    self?.activate(binding: binding)
                }
            }
        }
    }

    private func loadBindings() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return
        }
        do {
            let decoded = try JSONDecoder().decode([HotkeyBinding].self, from: data)
            bindings = decoded
        } catch {
            NSLog("Failed to decode bindings: \(error)")
        }
    }

    private func saveBindings() {
        do {
            let data = try JSONEncoder().encode(bindings)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            NSLog("Failed to encode bindings: \(error)")
        }
    }

    func clearPendingWindowSelection() {
        pendingWindowSelection = nil
    }

    func updateQuickBindingHotKey(_ descriptor: HotKeyDescriptor?) -> String? {
        if quickBindingHotKey == descriptor {
            return nil
        }

        if let descriptor,
           let conflict = bindings.first(where: { $0.hotKey == descriptor }) {
            return "Shortcut \(descriptor.readable) is already assigned to \(conflict.window.displayName). Choose a different combination."
        }

        let previous = quickBindingHotKey
        quickBindingHotKey = descriptor
        saveQuickBindingHotKey(descriptor)

        if let error = registerSetupHotKey() {
            quickBindingHotKey = previous
            saveQuickBindingHotKey(previous)
            _ = registerSetupHotKey()
            return error
        }

        return nil
    }

    private func prepareQuickBinding() {
        windowService.refreshWindows()
        pendingWindowSelection = windowService.frontmostWindow(excludingSelf: true)
        isRecordingHotkey = false
        MainWindowTracker.shared.showWindow()
    }

    private func registerSetupHotKey() -> String? {
        HotKeyManager.shared.unregisterActionHotKey(identifier: setupHotKeyIdentifier)
        guard let descriptor = quickBindingHotKey else {
            return nil
        }
        let success = HotKeyManager.shared.registerActionHotKey(identifier: setupHotKeyIdentifier,
                                                                descriptor: descriptor) { [weak self] in
            Task { @MainActor in
                self?.prepareQuickBinding()
            }
        }
        if !success {
            return "Failed to register quick binding shortcut \(descriptor.readable). Please choose another combination."
        }
        return nil
    }

    private func saveQuickBindingHotKey(_ descriptor: HotKeyDescriptor?) {
        if let descriptor {
            if let data = try? JSONEncoder().encode(descriptor) {
                UserDefaults.standard.set(data, forKey: Self.quickHotKeyStorageKey)
            }
        } else {
            UserDefaults.standard.removeObject(forKey: Self.quickHotKeyStorageKey)
        }
    }

    private static func loadQuickBindingHotKey() -> HotKeyDescriptor? {
        guard let data = UserDefaults.standard.data(forKey: quickHotKeyStorageKey) else {
            return nil
        }
        return try? JSONDecoder().decode(HotKeyDescriptor.self, from: data)
    }
}
