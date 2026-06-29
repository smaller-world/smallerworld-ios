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
    private var pendingMessages: [Message] = []

    deinit {
        if let tokenObserver {
            NotificationCenter.default.removeObserver(tokenObserver)
        }
    }

    override func onReceive(message: Message) {
        guard let event = Event(rawValue: message.event) else {
            return
        }

        switch event {
        case .connect:
            handleConnect()
        case .request:
            handleRequest(message: message)
        }
    }

    private func handleConnect() {
        // Observe device token deliveries for this component's lifetime. The
        // token is app-wide, so a single observer fulfills every in-flight
        // request once a token arrives. Guard against duplicate `connect`
        // deliveries so we only ever register one observer.
        guard tokenObserver == nil else { return }

        tokenObserver = NotificationCenter.default.addObserver(
            forName: .didReceiveDeviceToken,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let token = notification.object as? String else {
                return
            }

            // The observer is registered on the main queue, so we're already on
            // the main actor here.
            MainActor.assumeIsolated {
                self?.fulfillPendingRequests(token: token)
            }
        }
    }

    private func handleRequest(message: Message) {
        guard let data: RequestMessageData = message.data() else { return }

        // Track this request so we can reply to it once the token arrives.
        pendingMessages.append(message)

        var options: UNAuthorizationOptions = [.alert, .badge, .sound]
        if data.provisional {
            options.insert(.provisional)
        }

        UNUserNotificationCenter.current().requestAuthorization(options: options) {
            [weak self] granted, error in
            guard granted, error == nil else {
                Task { @MainActor [weak self] in
                    self?.pendingMessages.removeAll { $0.id == message.id }
                }
                return
            }

            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    private func fulfillPendingRequests(token: String) {
        let data = RequestReplyData(token: token)
        let messages = pendingMessages
        pendingMessages.removeAll()

        for message in messages {
            reply(with: message.replacing(data: data))
        }
    }

}

extension NotificationTokenComponent {
    fileprivate enum Event: String {
        case connect
        case request
    }

    fileprivate struct RequestMessageData: Decodable {
        let provisional: Bool
    }

    fileprivate struct RequestReplyData: Encodable, Sendable {
        let token: String
    }
}
