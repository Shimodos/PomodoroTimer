import Foundation
import ServiceManagement

/// "Open at login" through `SMAppService.mainApp` (SPEC §15). Errors are logged, never shown.
enum LoginItem {
    static var status: SMAppService.Status { SMAppService.mainApp.status }

    /// True when macOS wants the user to allow the item in System Settings → General → Login Items.
    static var requiresApproval: Bool { status == .requiresApproval }

    /// Save: register when on, unregister when off.
    static func apply(_ enabled: Bool, log: (String) -> Void) {
        do {
            if enabled {
                if status != .enabled { try SMAppService.mainApp.register() }
            } else if status == .enabled || status == .requiresApproval {
                try SMAppService.mainApp.unregister()
            }
            log("Login item: \(enabled ? "on" : "off"), status=\(describe(status))")
        } catch {
            log("Login item error: \(error.localizedDescription)")
        }
    }

    /// Launch: a setting that is on but not registered any more is registered again.
    static func syncAtLaunch(_ enabled: Bool, log: (String) -> Void) {
        guard enabled, status == .notRegistered else { return }
        apply(true, log: log)
    }

    private static func describe(_ s: SMAppService.Status) -> String {
        switch s {
        case .enabled: return "enabled"
        case .requiresApproval: return "requiresApproval"
        case .notRegistered: return "notRegistered"
        case .notFound: return "notFound"
        @unknown default: return "unknown"
        }
    }
}
