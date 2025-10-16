import SwiftUI
import AppKit
import Carbon

struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var hotKey: HotKeyDescriptor?
    var isEnabled: Bool = true

    func makeNSView(context: Context) -> HotkeyCaptureField {
        let field = HotkeyCaptureField(frame: .zero)
        field.placeholderString = "Press shortcut"
        field.isBezeled = true
        field.isEditable = false
        field.backgroundColor = .clear
        field.focusRingType = .none
        field.delegate = context.coordinator
        field.onCapture = { descriptor in
            hotKey = descriptor
        }
        return field
    }

    func updateNSView(_ nsView: HotkeyCaptureField, context: Context) {
        nsView.isEnabled = isEnabled
        if let hotKey {
            nsView.stringValue = hotKey.readable
        } else {
            nsView.stringValue = ""
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        private let parent: HotkeyRecorderView

        init(_ parent: HotkeyRecorderView) {
            self.parent = parent
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            guard let field = obj.object as? HotkeyCaptureField else { return }
            field.captureMode = true
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            guard let field = obj.object as? HotkeyCaptureField else { return }
            field.captureMode = false
        }
    }
}

final class HotkeyCaptureField: NSTextField {
    var onCapture: ((HotKeyDescriptor) -> Void)?
    var captureMode = false

    override var acceptsFirstResponder: Bool { true }
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        captureMode = true
    }

    override func becomeFirstResponder() -> Bool {
        captureMode = true
        return super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        captureMode = false
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        guard captureMode else {
            super.keyDown(with: event)
            return
        }
        if event.keyCode == UInt16(kVK_Escape) {
            stringValue = ""
            captureMode = false
            window?.makeFirstResponder(nil)
            return
        }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let descriptor = HotKeyDescriptor(keyCode: UInt32(event.keyCode), modifiers: flags.carbonFlags)
        onCapture?(descriptor)
        captureMode = false
        window?.makeFirstResponder(nil)
    }

    override func flagsChanged(with event: NSEvent) {
        guard captureMode else {
            super.flagsChanged(with: event)
            return
        }
        // Ignore standalone modifier changes.
    }
}

extension NSEvent.ModifierFlags {
    var carbonFlags: UInt32 {
        var result: UInt32 = 0
        if contains(.command) { result |= UInt32(cmdKey) }
        if contains(.option) { result |= UInt32(optionKey) }
        if contains(.control) { result |= UInt32(controlKey) }
        if contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }
}
