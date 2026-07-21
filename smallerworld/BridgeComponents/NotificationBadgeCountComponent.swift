import Foundation
import HotwireNative
import UIKit
import UserNotifications
import os

final class NotificationBadgeCountComponent: BridgeComponent {
    override nonisolated class var name: String { "notification-badge-count" }

    override func onReceive(message: Message) {
        guard let event = Event(rawValue: message.event) else {
            return
        }

        switch event {
        case .clear:
            handleClear()
        }
    }

    private func handleClear() {
        UNUserNotificationCenter.current().setBadgeCount(0) { [weak self] error in
            if let error {
                let description = error.localizedDescription
                logger.error(
                    "Failed to clear badge count: \(description, privacy: .public)"
                )
                DispatchQueue.main.async { [weak self] in
                    self?.reply(
                        to: Event.clear.rawValue,
                        with: ClearReplyData(error: description)
                    )
                }
                return
            }

            DispatchQueue.main.async { [weak self] in
                self?.reply(
                    to: Event.clear.rawValue,
                    with: ClearReplyData(error: nil)
                )
            }
        }
    }
}

extension NotificationBadgeCountComponent {
    fileprivate enum Event: String {
        case clear
    }

    fileprivate struct ClearReplyData: Encodable, Sendable {
        let error: String?
    }
}
