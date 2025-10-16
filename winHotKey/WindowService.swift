import AppKit
import Combine

final class WindowService: ObservableObject {
    static let shared = WindowService()

    @Published private(set) var windows: [WindowInfo] = []
    private var timer: AnyCancellable?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []

    private init() {
        startRefreshing()
        startObservingWorkspace()
    }

    func startRefreshing() {
        timer?.cancel()
        timer = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshWindows()
            }
        refreshWindows()
    }

    func stopRefreshing() {
        timer?.cancel()
        timer = nil
    }

    func refreshWindows() {
        let options: CGWindowListOption = [.excludeDesktopElements, .optionOnScreenOnly]
        guard let infos = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            windows = []
            return
        }

        var result: [WindowInfo] = []
        for info in infos {
            if let windowInfo = windowInfo(from: info) {
                result.append(windowInfo)
            }
        }
        let unique = result.uniqued()
        windows = unique.disambiguatingDuplicates()
    }

    func frontmostWindow(excludingSelf: Bool = true) -> WindowInfo? {
        let currentWindows = windows
        let selfPID = getpid()

        if let frontApp = NSWorkspace.shared.frontmostApplication {
            let pid = frontApp.processIdentifier
            if !(excludingSelf && pid == selfPID),
               let match = currentWindows.first(where: { $0.ownerPID == pid }) {
                return match
            }
        }

        let options: CGWindowListOption = [.excludeDesktopElements, .optionOnScreenOnly]
        guard let infos = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        for info in infos {
            guard let candidate = windowInfo(from: info) else { continue }
            if excludingSelf, candidate.ownerPID == selfPID {
                continue
            }
            if let match = currentWindows.first(where: { $0.windowNumber == candidate.windowNumber }) {
                return match
            }
        }

        return nil
    }

    private static func bundleIdentifier(for pid: pid_t) -> String? {
        guard let app = NSRunningApplication(processIdentifier: pid_t(pid)) else {
            return nil
        }
        return app.bundleIdentifier
    }

    deinit {
        stopRefreshing()
        stopObservingWorkspace()
    }

    private func startObservingWorkspace() {
        stopObservingWorkspace()

        let center = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didDeactivateApplicationNotification,
            NSWorkspace.didHideApplicationNotification,
            NSWorkspace.didUnhideApplicationNotification,
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification
        ]

        for name in names {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.refreshWindows()
            }
            observers.append((center, token))
        }

        let localCenter = NotificationCenter.default
        let localNames: [Notification.Name] = [
            NSApplication.didBecomeActiveNotification,
            NSApplication.didResignActiveNotification,
            NSWindow.didBecomeMainNotification,
            NSWindow.didResignMainNotification
        ]

        for name in localNames {
            let token = localCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.refreshWindows()
            }
            observers.append((localCenter, token))
        }
    }

    private func stopObservingWorkspace() {
        for (center, token) in observers {
            center.removeObserver(token)
        }
        observers.removeAll()
    }

    private func windowInfo(from info: [String: Any]) -> WindowInfo? {
        guard
            let layer = info[kCGWindowLayer as String] as? Int,
            layer == 0,
            let pid = info[kCGWindowOwnerPID as String] as? pid_t,
            let windowNumber = info[kCGWindowNumber as String] as? UInt32,
            let ownerName = info[kCGWindowOwnerName as String] as? String
        else {
            return nil
        }

        let ignoredOwners: Set<String> = ["Window Server", "Control Center", "Notification Center"]
        if ignoredOwners.contains(ownerName) {
            return nil
        }

        if pid == getpid() {
            return nil
        }

        let windowTitle = (info[kCGWindowName as String] as? String) ?? ""
        let bundleIdentifier = Self.bundleIdentifier(for: pid)

        if let mainBundleID = Bundle.main.bundleIdentifier,
           bundleIdentifier == mainBundleID {
            return nil
        }

        return WindowInfo(
            ownerName: ownerName,
            ownerPID: pid,
            windowNumber: CGWindowID(windowNumber),
            title: windowTitle,
            bundleIdentifier: bundleIdentifier
        )
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

private extension Array where Element == WindowInfo {
    func disambiguatingDuplicates() -> [WindowInfo] {
        let groups = Dictionary(grouping: self) { $0.displayName }
        var numbering: [WindowInfo: Int] = [:]

        for windows in groups.values where windows.count > 1 {
            let sorted = windows.sorted { $0.windowNumber < $1.windowNumber }
            for (index, window) in sorted.enumerated() {
                numbering[window] = index + 1
            }
        }

        return map { window in
            guard let index = numbering[window] else {
                return window
            }

            let suffix = "(\(index))"
            let annotatedTitle: String
            if window.title.isEmpty {
                annotatedTitle = suffix
            } else {
                annotatedTitle = "\(window.title) \(suffix)"
            }

            return WindowInfo(
                ownerName: window.ownerName,
                ownerPID: window.ownerPID,
                windowNumber: window.windowNumber,
                title: annotatedTitle,
                bundleIdentifier: window.bundleIdentifier
            )
        }
    }
}
