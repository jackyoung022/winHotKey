import AppKit
import ApplicationServices

enum WindowActivator {
    static func activate(window: WindowInfo) {
        guard AccessibilityPermissionManager.shared.status == .authorized else {
            return
        }

        guard let app = NSRunningApplication(processIdentifier: window.ownerPID) else {
            return
        }

        let applicationElement = AXUIElementCreateApplication(window.ownerPID)
        var value: AnyObject?
        let status = AXUIElementCopyAttributeValue(applicationElement,
                                                   kAXWindowsAttribute as CFString,
                                                   &value)

        if status == .success,
           let windowElements = value as? [AXUIElement],
           let target = windowElements.first(where: { matches(element: $0, window: window) }) ?? windowElements.first {
            AXUIElementSetAttributeValue(applicationElement, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
            AXUIElementPerformAction(target, kAXRaiseAction as CFString)
            AXUIElementSetAttributeValue(target, kAXMainAttribute as CFString, kCFBooleanTrue)
            AXUIElementSetAttributeValue(target, kAXFocusedAttribute as CFString, kCFBooleanTrue)
            bringAppToFront(app)
        } else {
            bringAppToFront(app)
        }
    }

    private static func matches(element: AXUIElement, window: WindowInfo) -> Bool {
        var titleValue: AnyObject?
        let titleStatus = AXUIElementCopyAttributeValue(element,
                                                        kAXTitleAttribute as CFString,
                                                        &titleValue)
        if titleStatus == .success,
           let currentTitle = titleValue as? String,
           !currentTitle.isEmpty,
           !window.title.isEmpty,
           currentTitle == window.title {
            return true
        }
        return false
    }

    private static func bringAppToFront(_ app: NSRunningApplication) {
        if #available(macOS 14.0, *) {
            app.activate()
        } else {
            app.activate(options: [.activateIgnoringOtherApps])
        }
    }
}
