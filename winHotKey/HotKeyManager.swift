import AppKit
import Carbon

final class HotKeyManager {
    static let shared = HotKeyManager()

    private enum RegistrationKind {
        case binding(UUID)
        case action(String)
    }

    private struct Registration {
        let hotKeyID: UInt32
        let descriptor: HotKeyDescriptor
        let kind: RegistrationKind
    }

    private var registrations: [UUID: Registration] = [:]
    private var callbacks: [UInt32: () -> Void] = [:]
    private var hotKeyReferences: [UUID: EventHotKeyRef] = [:]
    private var currentID: UInt32 = 1
    private var eventHandlerInstalled = false
    private var actionIdentifiers: [String: UUID] = [:]

    private init() {
        installEventHandlerIfNeeded()
    }

    func register(binding: HotkeyBinding, callback: @escaping () -> Void) {
        removeHotKey(for: binding.id)
        guard binding.isEnabled else { return }

        _ = installHotKey(id: binding.id,
                          descriptor: binding.hotKey,
                          kind: .binding(binding.id),
                          callback: callback)
    }

    @discardableResult
    func registerActionHotKey(identifier: String, descriptor: HotKeyDescriptor, callback: @escaping () -> Void) -> Bool {
        if let existing = actionIdentifiers[identifier] {
            removeHotKey(for: existing)
        }

        let id = UUID()
        let success = installHotKey(id: id,
                                    descriptor: descriptor,
                                    kind: .action(identifier),
                                    callback: callback)
        if success {
            actionIdentifiers[identifier] = id
        }
        return success
    }

    func unregisterActionHotKey(identifier: String) {
        if let id = actionIdentifiers[identifier] {
            removeHotKey(for: id)
        }
    }

    func removeHotKey(for id: UUID) {
        guard let registration = registrations.removeValue(forKey: id) else { return }

        if let ref = hotKeyReferences.removeValue(forKey: id) {
            UnregisterEventHotKey(ref)
        }
        callbacks.removeValue(forKey: registration.hotKeyID)

        if case let .action(identifier) = registration.kind {
            actionIdentifiers.removeValue(forKey: identifier)
        }
    }

    func clearBindings() {
        let ids = registrations.compactMap { entry -> UUID? in
            if case .binding = entry.value.kind {
                return entry.key
            }
            return nil
        }
        ids.forEach { removeHotKey(for: $0) }
    }

    func clearAll() {
        let ids = Array(registrations.keys)
        ids.forEach { removeHotKey(for: $0) }
        currentID = 1
        actionIdentifiers.removeAll()
    }

    private func installHotKey(id: UUID,
                               descriptor: HotKeyDescriptor,
                               kind: RegistrationKind,
                               callback: @escaping () -> Void) -> Bool {
        let hotKeyID = EventHotKeyID(signature: OSType("WHKY".fourCharCodeValue), id: nextIdentifier())
        var hotKeyRef: EventHotKeyRef?

        let status = RegisterEventHotKey(descriptor.keyCode,
                                         descriptor.modifiers,
                                         hotKeyID,
                                         GetEventDispatcherTarget(),
                                         0,
                                         &hotKeyRef)
        guard status == noErr, let ref = hotKeyRef else {
            describeRegistrationFailure(status, descriptor: descriptor)
            return false
        }

        registrations[id] = Registration(hotKeyID: hotKeyID.id, descriptor: descriptor, kind: kind)
        callbacks[hotKeyID.id] = callback
        hotKeyReferences[id] = ref
        return true
    }

    private func handleHotKey(id: UInt32) {
        callbacks[id]?()
    }

    private func nextIdentifier() -> UInt32 {
        let identifier = currentID
        currentID = currentID == UInt32.max ? 1 : currentID + 1
        return identifier
    }

    private func installEventHandlerIfNeeded() {
        guard !eventHandlerInstalled else { return }
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(GetEventDispatcherTarget(), { (_, event, _) -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(event,
                                           EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID),
                                           nil,
                                           MemoryLayout<EventHotKeyID>.size,
                                           nil,
                                           &hotKeyID)
            if status != noErr {
                return status
            }
            HotKeyManager.shared.handleHotKey(id: hotKeyID.id)
            return noErr
        }, 1, &eventSpec, nil, nil)
        eventHandlerInstalled = true
    }

    private func describeRegistrationFailure(_ status: OSStatus, descriptor: HotKeyDescriptor) {
        guard status != noErr else { return }

        let description: String
        switch status {
        case OSStatus(eventHotKeyExistsErr):
            description = "A global shortcut with the same combination already exists."
        case OSStatus(eventNotHandledErr):
            description = "The system could not handle the hotkey event."
        case OSStatus(eventHotKeyInvalidErr):
            description = "The hotkey parameters are invalid."
        default:
            description = "OSStatus \(status)"
        }
        NSLog("Failed to register hotkey \(descriptor.readable): \(description)")
    }
}

private extension String {
    var fourCharCodeValue: FourCharCode {
        var result: FourCharCode = 0
        for (index, scalar) in unicodeScalars.prefix(4).enumerated() {
            let shift = UInt32((3 - index) * 8)
            result |= FourCharCode(UInt32(scalar.value) << shift)
        }
        return result
    }
}
