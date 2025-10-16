import AppKit
import ApplicationServices
import Combine

final class AccessibilityPermissionManager: ObservableObject {
    static let shared = AccessibilityPermissionManager()

    @Published private(set) var status: AccessibilityStatus = .unknown

    private init() {
        refreshStatus()
    }

    func refreshStatus() {
        let trusted = AXIsProcessTrusted()
        status = trusted ? .authorized : .denied
    }

    func requestAccess() -> PermissionRequestResult {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let granted = AXIsProcessTrustedWithOptions(options)
        refreshStatus()
        return granted ? .granted : .requiresManual
    }
}
