import Foundation
import HotwireNative
import UIKit
import UserNotifications

extension Notification.Name {
    static let didReceiveDeviceToken = Notification.Name("didReceiveDeviceToken")
}

final class NotificationTokenComponent: BridgeComponent {
    override nonisolated class var name: String { "notification-token" }

    private var tokenObserver: NSObjectProtocol?

    override func onReceive(message: Message) {
        guard let event = Event(rawValue: message.event) else {
            return
        }

        switch event {
        case .connect:
            handleConnect()
        case .get:
            handleRequest(message: message)
        }
    }

    deinit {
        if let observer = tokenObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func handleRequest(message: Message) {
        guard let data: RequestMessageData = message.data() else { return }

        var options: UNAuthorizationOptions = [.alert, .badge, .sound]
        if data.provisional {
            options.insert(.provisional)
        }

        UNUserNotificationCenter.current().requestAuthorization(options: options) {
            granted, error in
            guard granted, error == nil else { return }

            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    private func handleConnect() {
        // Set up observer for when we receive the token from AppDelegate.
        if tokenObserver == nil {
            tokenObserver = NotificationCenter.default.addObserver(
                forName: .didReceiveDeviceToken,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard
                    let self,
                    let deviceToken = notification.object as? Data
                else {
                    return
                }

                let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
                let data = RequestReplyData(token: token)
                Task { @MainActor in
                    self.reply(to: Event.get.rawValue, with: data)
                }
            }
        }
    }
}

extension NotificationTokenComponent {
    fileprivate enum Event: String {
        case connect
        case get
    }

    fileprivate struct RequestMessageData: Decodable {
        let provisional: Bool
    }

    fileprivate struct RequestReplyData: Encodable, Sendable {
        let token: String
    }
}
