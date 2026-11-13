import AppKit
import Foundation
import ServiceManagement
import UniformTypeIdentifiers

enum CaptureSource {
    case screen(forceInteractive: Bool)
    case clipboard
    case file(URL)
}

struct LaunchOptions {
    var mode: RunMode = .oneShot(.screen(forceInteractive: false))
    var delaySeconds: Double = 0
    var outputDirectory: URL?
    var autoSaveOnConfirm: Bool = false

    enum RunMode {
        case oneShot(CaptureSource)
        case menuBar
        case help
        case version
    }
}

final class AppController: NSObject, NSApplicationDelegate {
    private let options: LaunchOptions
    private var overlayWindow: OverlayWindow?
    private var statusItem: NSStatusItem?
    private let hotKeyManager = HotKeyManager()
    private var initialCaptureResult: CaptureResult?

    private var launchAtLoginItem: NSMenuItem?
    private var screenAccessItem: NSMenuItem?
    private var permissionObserver: NSObjectProtocol?

    init(options: LaunchOptions, initialCaptureResult: CaptureResult? = nil) {
        self.options = options
        self.initialCaptureResult = initialCaptureResult
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        switch options.mode {
        case .oneShot:
            if let result = initialCaptureResult {
                initialCaptureResult = nil
                presentOverlay(with: result, terminateOnFinish: true)
            } else {
                NSApp.terminate(nil)
            }

        case .menuBar:
            setupMenuBar()
            hotKeyManager.register { [weak self] in
                self?.triggerMenuCapture(forceInteractive: false)
            }
            observePermissionChanges()
            PermissionManager.showOnboardingIfNeeded(hotkey: "⌃⌘A")

        case .help, .version:
            NSApp.terminate(nil)
        }
    }

    /// Re-check Screen Recording status whenever the app becomes active again,
    /// e.g. right after the user flips the switch in System Settings.
    private func observePermissionChanges() {
        permissionObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshMenuState()
        }
    }

    private func refreshMenuState() {
        if let item = launchAtLoginItem {
            switch SMAppService.mainApp.status {
            case .enabled:
                item.state = .on
                item.title = "Launch at Login"
            case .requiresApproval:
                item.state = .off
                item.title = "Launch at Login (approve in System Settings)"
            default:
                item.state = .off
                item.title = "Launch at Login"
            }
        }
        if let item = screenAccessItem {
            if PermissionManager.isGranted {
                item.state = .on
                item.title = "Screen Recording Access"
            } else {
                item.state = .off
                item.title = "Screen Recording Access (not granted)"
            }
        }
    }

    private func setupMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            if let img = NSImage(
                systemSymbolName: "viewfinder.rectangular",
                accessibilityDescription: "QSnip"
            ) {
                img.isTemplate = true
                button.image = img
            } else {
                button.title = "✂︎"
            }
            button.toolTip = "QSnip — Screenshot & Annotate (⌃⌘A)"
        }

        let menu = NSMenu()

        let snipItem = NSMenuItem(
            title: "Capture Region",
            action: #selector(onMenuSnip),
            keyEquivalent: "a"
        )
        snipItem.keyEquivalentModifierMask = [.command, .control]
        snipItem.target = self
        menu.addItem(snipItem)

        let interactiveItem = NSMenuItem(
            title: "Interactive Capture",
            action: #selector(onMenuInteractiveSnip),
            keyEquivalent: ""
        )
        interactiveItem.target = self
        menu.addItem(interactiveItem)

        let delayItem = NSMenuItem(
            title: "Capture in 3 Seconds",
            action: #selector(onMenuDelayedSnip),
            keyEquivalent: ""
        )
        delayItem.target = self
        menu.addItem(delayItem)

        menu.addItem(.separator())

        let clipItem = NSMenuItem(
            title: "Annotate from Clipboard",
            action: #selector(onMenuClipboard),
            keyEquivalent: ""
        )
        clipItem.target = self
        menu.addItem(clipItem)

        let openItem = NSMenuItem(
            title: "Open Image File…",
            action: #selector(onMenuOpenFile),
            keyEquivalent: "o"
        )
        openItem.keyEquivalentModifierMask = [.command]
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        let launchItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(onToggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchItem.target = self
        menu.addItem(launchItem)
        self.launchAtLoginItem = launchItem

        let accessItem = NSMenuItem(
            title: "Screen Recording Access",
            action: #selector(onRequestScreenAccess),
            keyEquivalent: ""
        )
        accessItem.target = self
        menu.addItem(accessItem)
        self.screenAccessItem = accessItem

        menu.addItem(.separator())

        let versionItem = NSMenuItem(
            title: "QSnip v\(Version.current)",
            action: nil,
            keyEquivalent: ""
        )
        versionItem.isEnabled = false
        menu.addItem(versionItem)

        let quitItem = NSMenuItem(
            title: "Quit QSnip",
            action: #selector(onMenuQuit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        self.statusItem = item
        refreshMenuState()
    }

    @objc private func onToggleLaunchAtLogin() {
        let enabling = !LaunchAtLogin.isEnabled
        if let error = LaunchAtLogin.setEnabled(enabling) {
            NSSound.beep()
            let alert = NSAlert()
            alert.messageText = "Launch at Login"
            alert.informativeText = error
            alert.alertStyle = .warning
            alert.runModal()
        }
        if LaunchAtLogin.needsApproval {
            LaunchAtLogin.openSystemSettings()
        }
        refreshMenuState()
    }

    @objc private func onRequestScreenAccess() {
        guard !PermissionManager.isGranted else { return }
        PermissionManager.request()
        PermissionManager.openSystemSettings()
    }

    @objc private func onMenuSnip() {
        triggerMenuCapture(forceInteractive: false, delay: 0.12)
    }

    @objc private func onMenuInteractiveSnip() {
        triggerMenuCapture(forceInteractive: true, delay: 0.12)
    }

    @objc private func onMenuDelayedSnip() {
        triggerMenuCapture(forceInteractive: false, delay: 3.0)
    }

    @objc private func onMenuClipboard() {
        guard overlayWindow == nil else { return }
        guard let cgImage = ScreenCapturer.loadFromClipboard() else {
            NSSound.beep()
            return
        }
        let result = CaptureResult.region(image: cgImage, screen: ScreenCapturer.activeScreen())
        presentOverlay(with: result, terminateOnFinish: false)
    }

    @objc private func onMenuOpenFile() {
        guard overlayWindow == nil else { return }
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url,
            let cgImage = ScreenCapturer.loadCGImage(from: url)
        {
            let result = CaptureResult.region(image: cgImage, screen: ScreenCapturer.activeScreen())
            presentOverlay(with: result, terminateOnFinish: false)
        }
    }

    @objc private func onMenuQuit() {
        NSApp.terminate(nil)
    }

    private func triggerMenuCapture(forceInteractive: Bool, delay: TimeInterval = 0) {
        guard overlayWindow == nil else { return }
        let work = { [weak self] in
            guard let self, let result = ScreenCapturer.capture(forceInteractive: forceInteractive) else {
                return
            }
            self.presentOverlay(with: result, terminateOnFinish: false)
        }
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        } else {
            work()
        }
    }

    func presentOverlay(with captureResult: CaptureResult, terminateOnFinish: Bool) {
        closeOverlay()

        let window = OverlayWindow(captureResult: captureResult)
        let canvas = window.canvasView
        canvas.customOutputDirectory = options.outputDirectory
        canvas.autoSaveOnConfirm = options.autoSaveOnConfirm

        canvas.onFinish = { [weak self] outcome in
            guard let self else { return }
            self.closeOverlay()
            switch outcome {
            case .saved(let url):
                if terminateOnFinish {
                    print(url.path)
                }
            case .copiedText(let text):
                if terminateOnFinish {
                    print(text)
                }
            case .copied, .cancelled:
                break
            }
            if terminateOnFinish {
                let code: Int32 = {
                    if case .cancelled = outcome { return 1 }
                    return 0
                }()
                exit(code)
            }
        }

        self.overlayWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(canvas)
    }

    private func closeOverlay() {
        guard let window = overlayWindow else { return }
        overlayWindow = nil
        window.orderOut(nil)
        window.close()
    }
}
