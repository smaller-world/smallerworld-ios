import Foundation
import HotwireNative
import UIKit
import UserNotifications

final class NotificationPermissionComponent: BridgeComponent {
    override nonisolated class var name: String { "notification-permission" }

    override func onReceive(message: Message) {
        guard let event = Event(rawValue: message.event) else {
            return
        }

        switch event {
        case .connect:
            handleConnect()
        }
    }

    private func handleConnect() {
        UNUserNotificationCenter.current().getNotificationSettings {
            [weak self] settings in
            guard let self else { return }

            let permission = mapAuthorizationStatus(settings.authorizationStatus)
            let data = ConnectMessageData(permission: permission)
            Task { @MainActor in
                self.reply(to: Event.connect.rawValue, with: data)
            }
        }
    }
}

extension NotificationPermissionComponent {
    fileprivate enum Event: String {
        case connect
    }

    fileprivate enum NotificationPermission: String, Encodable, Sendable {
        case granted
        case denied
        case indeterminate
    }

    fileprivate struct ConnectMessageData: Encodable, Sendable {
        let permission: NotificationPermission
    }

    fileprivate nonisolated func mapAuthorizationStatus(
        _ status: UNAuthorizationStatus
    ) -> NotificationPermission {
        switch status {
        case .authorized:
            return .granted
        case .denied:
            return .denied
        case .notDetermined, .provisional, .ephemeral:
            return .indeterminate
        @unknown default:
            return .indeterminate
        }
    }
}
