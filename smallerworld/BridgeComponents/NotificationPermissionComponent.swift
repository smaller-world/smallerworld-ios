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

            let permission = NotificationPermission(settings.authorizationStatus)
            let data = ConnectReplyData(permission: permission)
            DispatchQueue.main.async {
                self.reply(to: Event.connect.rawValue, with: data)
            }
        }
    }
}

extension NotificationPermissionComponent {
    fileprivate enum Event: String {
        case connect
    }

    fileprivate struct ConnectReplyData: Encodable, Sendable {
        let permission: NotificationPermission
    }
}
