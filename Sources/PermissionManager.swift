import AppKit
import CoreGraphics
import Foundation

/// Screen Recording permission (TCC). Reading status never triggers a system prompt;
/// `request()` does, and after the user changes the setting macOS requires a relaunch.
enum PermissionManager {
    static var isGranted: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Presents the system Screen Recording prompt if not yet granted.
    /// Returns true when access is already active.
    @discardableResult
    static func request() -> Bool {
        if isGranted { return true }
        return CGRequestScreenCaptureAccess()
    }

    static func openSystemSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    /// First-launch guidance for menu-bar mode: explains the hotkey and walks the
    /// user through granting Screen Recording. Skipped entirely once granted and shown.
    @MainActor
    static func showOnboardingIfNeeded(hotkey: String) {
        let seenKey = "QSnipOnboardingShown"
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: seenKey), isGranted { return }

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Welcome to QSnip"
        alert.informativeText = """
            Press \(hotkey) anywhere, or use the menu bar icon, to snip and annotate.

            For the best experience, QSnip needs Screen Recording permission so it can \
            freeze the screen silently (Snipaste-style). Without it, capture falls back \
            to the macOS interactive crosshair.

            After granting access in System Settings, relaunch QSnip for it to take effect.
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Not Now")
        if alert.runModal() == .alertFirstButtonReturn {
            request()
            openSystemSettings()
        }
        defaults.set(true, forKey: seenKey)
    }
}
