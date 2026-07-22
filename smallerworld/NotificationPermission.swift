import UserNotifications

/// The notification permission states exposed to the web bridge.
///
/// iOS distinguishes more states than we surface (e.g. `.ephemeral`), so we
/// coalesce the real `UNAuthorizationStatus` down to the four cases the web
/// side understands.
enum NotificationPermission: String, Encodable, Sendable {
    case authorized
    case provisional
    case denied
    case indeterminate

    init(_ status: UNAuthorizationStatus) {
        switch status {
        case .authorized:
            self = .authorized
        case .provisional, .ephemeral:
            self = .provisional
        case .denied:
            self = .denied
        case .notDetermined:
            self = .indeterminate
        @unknown default:
            self = .indeterminate
        }
    }
}
