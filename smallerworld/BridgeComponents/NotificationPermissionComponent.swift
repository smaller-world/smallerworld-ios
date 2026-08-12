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
        case .get:
            handleGet()
        }
    }

    private func handleGet() {
        UNUserNotificationCenter.current().getNotificationSettings {
            [weak self] settings in
            guard let self else { return }

            let permission = NotificationPermission(settings.authorizationStatus)
            let data = GetReplyData(permission: permission)
            DispatchQueue.main.async {
                self.reply(to: Event.get.rawValue, with: data)
            }
        }
    }
}

extension NotificationPermissionComponent {
    fileprivate enum Event: String {
        case get
    }

    fileprivate struct GetReplyData: Encodable, Sendable {
        let permission: NotificationPermission
    }
}
