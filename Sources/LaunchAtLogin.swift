import Foundation
import ServiceManagement

/// Login item backed by `SMAppService` (macOS 13+).
/// Registering requires the app to be launched from its final `.app` bundle;
/// unbundled binaries (e.g. `.build/debug/qsnip`) report `.unsupported`.
enum LaunchAtLogin {
    private static var service: SMAppService { SMAppService.mainApp }

    static var isEnabled: Bool {
        service.status == .enabled
    }

    static var needsApproval: Bool {
        service.status == .requiresApproval
    }

    /// Returns nil on success, or a user-facing error message.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> String? {
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
