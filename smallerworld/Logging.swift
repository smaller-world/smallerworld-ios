import Foundation
import os

/// App-wide `os.log` loggers, split by category so Console.app can filter
/// each subsystem independently instead of grepping bracket-prefixes.
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier!

    static let app = Logger(subsystem: subsystem, category: "app")
    static let routing = Logger(subsystem: subsystem, category: "routing")
    static let notifications = Logger(subsystem: subsystem, category: "notificationService")
}
