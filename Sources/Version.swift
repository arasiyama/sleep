import Foundation

/// Single source of truth for the app version.
/// `make app` / `make dist` stamps this value into Info.plist.
enum Version {
    static let current = "1.1.0"
}
