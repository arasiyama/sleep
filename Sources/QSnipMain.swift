import AppKit
import Foundation

@main
enum QSnipMain {
    static let version = "1.0.0"

    static func parseArguments(_ args: [String], isAppBundle: Bool = false) throws -> LaunchOptions {
        var opts = LaunchOptions()
        var explicitModeSet = false

        var idx = 1
        while idx < args.count {
            let arg = args[idx]
            switch arg {
            case "-h", "--help":
                opts.mode = .help
                return opts

            case "-v", "--version":
                opts.mode = .version
                return opts

            case "-m", "--menubar":
                opts.mode = .menuBar
                explicitModeSet = true

            case "--once":
                opts.mode = .oneShot(.screen(forceInteractive: false))
                explicitModeSet = true

            case "-i", "--interactive":
                opts.mode = .oneShot(.screen(forceInteractive: true))
                explicitModeSet = true

            case "-c", "--clipboard":
                opts.mode = .oneShot(.clipboard)
                explicitModeSet = true

            case "-f", "--file":
                idx += 1
                guard idx < args.count else {
                    throw NSError(domain: "QSnip", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing file path after \(arg)"])
                }
                let path = (args[idx] as NSString).expandingTildeInPath
                opts.mode = .oneShot(.file(URL(fileURLWithPath: path)))
                explicitModeSet = true

            case "-o", "--output":
                idx += 1
                guard idx < args.count else {
                    throw NSError(domain: "QSnip", code: 2, userInfo: [NSLocalizedDescriptionKey: "Missing directory path after \(arg)"])
                }
                let path = (args[idx] as NSString).expandingTildeInPath
                opts.outputDirectory = URL(fileURLWithPath: path, isDirectory: true)

            case "-d", "--delay":
                idx += 1
                guard idx < args.count, let sec = Double(args[idx]), sec >= 0 else {
                    throw NSError(domain: "QSnip", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid delay value after \(arg)"])
                }
                opts.delaySeconds = sec

            case "--autosave":
                opts.autoSaveOnConfirm = true

            default:
                // Ignore macOS LaunchServices `-psn_...` or Xcode debugger flags
                if arg.hasPrefix("-psn_") || arg == "-NSDocumentRevisionsDebugMode" {
                    if arg == "-NSDocumentRevisionsDebugMode" { idx += 1 }
                } else {
                    throw NSError(domain: "QSnip", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown option: \(arg)"])
                }
            }
            idx += 1
        }

        if isAppBundle && !explicitModeSet {
            opts.mode = .menuBar
        }
        return opts
    }

    static func printHelp() {
        let help = """
        QSnip \(version) — Lightweight Snipaste-style screenshot & annotation tool for macOS

        USAGE:
          qsnip [OPTIONS]

        MODES:
          (default)              Freeze active screen & select region in-place (Snipaste mode)
          -i, --interactive      Use macOS interactive crosshair capture, then annotate
          -c, --clipboard        Open image currently on the clipboard for annotation
          -f, --file <path>      Open an image file from disk for annotation
          -m, --menubar          Run persistently in macOS Menu Bar (global hotkey: ⌃⌘A)
          --once                 Force one-shot capture even when invoked from QSnip.app

        OPTIONS:
          -d, --delay <sec>      Wait <sec> seconds before capturing screen
          -o, --output <dir>     Directory for saved PNG files (default: ~/Desktop)
          --autosave             Also save PNG to output directory upon confirm (✓ / Enter)
          -v, --version          Show version
          -h, --help             Show this help message

        SHORTCUTS IN OVERLAY:
          1 / 2 / 3              Rectangle / Ellipse / Arrow annotation tool
          [ / ]                  Decrease / increase stroke width
          Shift (drag)           Square / circle / 45° snapped arrow
          ⌘Z / ⇧⌘Z               Undo / Redo annotation
          Delete                 Remove selected annotation (or undo last)
          Enter / ⌘C / DblClick  Copy annotated screenshot to clipboard & exit
          ⌘S / ⇧⌘S               Save PNG to output folder / Save As…
          C (before selection)   Copy cursor pixel #RRGGBB hex color to clipboard
          Right-Click            Deselect tool → reset selection → cancel
          Esc                    Cancel & exit immediately
        """
        print(help)
    }

    static func main() {
        let isAppBundle = Bundle.main.bundleURL.pathExtension.lowercased() == "app"
        let options: LaunchOptions
        do {
            options = try parseArguments(CommandLine.arguments, isAppBundle: isAppBundle)
        } catch {
            FileHandle.standardError.write(Data("Error: \(error.localizedDescription)\nRun 'qsnip --help' for usage.\n".utf8))
            exit(2)
        }

        switch options.mode {
        case .help:
            printHelp()
            exit(0)
        case .version:
            print("QSnip \(version)")
            exit(0)
        case .menuBar:
            let app = NSApplication.shared
            app.setActivationPolicy(.accessory)
            let controller = AppController(options: options)
            app.delegate = controller
            app.run()

        case .oneShot(let source):
            if options.delaySeconds > 0 {
                Thread.sleep(forTimeInterval: options.delaySeconds)
            }
            let app = NSApplication.shared
            app.setActivationPolicy(.accessory)

            let captureResult: CaptureResult?
            switch source {
            case .screen(let forceInteractive):
                captureResult = ScreenCapturer.capture(forceInteractive: forceInteractive)
            case .clipboard:
                if let img = ScreenCapturer.loadFromClipboard() {
                    captureResult = .region(image: img, screen: ScreenCapturer.activeScreen())
                } else {
                    FileHandle.standardError.write(Data("Error: No image found on the clipboard.\n".utf8))
                    exit(1)
                }
            case .file(let url):
                if let img = ScreenCapturer.loadCGImage(from: url) {
                    captureResult = .region(image: img, screen: ScreenCapturer.activeScreen())
                } else {
                    FileHandle.standardError.write(Data("Error: Could not load image at '\(url.path)'.\n".utf8))
                    exit(1)
                }
            }

            guard let result = captureResult else {
                exit(1)
            }

            let controller = AppController(options: options, initialCaptureResult: result)
            app.delegate = controller
            app.run()
        }
    }
}
