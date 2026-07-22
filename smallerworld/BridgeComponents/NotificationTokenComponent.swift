import Foundation
import HotwireNative
import UIKit
import UserNotifications
import os

extension Notification.Name {
    static let didReceiveDeviceToken = Notification.Name("didReceiveDeviceToken")
    static let didFailToRegisterForRemoteNotifications = Notification.Name(
        "didFailToRegisterForRemoteNotifications"
    )
}

final class NotificationTokenComponent: BridgeComponent {
    override nonisolated class var name: String { "notification-token" }

    private var tokenObserver: NSObjectProtocol?
    private var failureObserver: NSObjectProtocol?
    private var pendingMessages: [Message] = []

    deinit {
        if let tokenObserver {
            NotificationCenter.default.removeObserver(tokenObserver)
        }
        if let failureObserver {
            NotificationCenter.default.removeObserver(failureObserver)
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
        // Observe device token deliveries and registration failures for this
        // component's lifetime. Both outcomes are app-wide, so a single pair of
        // observers fulfills every in-flight request once APNs responds. Guard
        // against duplicate `connect` deliveries so we only ever register once.
        guard tokenObserver == nil else { return }

        tokenObserver = NotificationCenter.default.addObserver(
            forName: .didReceiveDeviceToken,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let token = notification.object as? String else {
                return
            }
            self?.resolvePendingRequests(token: token, error: nil)
        }

        failureObserver = NotificationCenter.default.addObserver(
            forName: .didFailToRegisterForRemoteNotifications,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let message = notification.object as? String
            self?.resolvePendingRequests(
                token: nil,
                error: message ?? "Failed to register for remote notifications"
            )
        }
    }

    private func handleRequest(message: Message) {
        guard let data: RequestMessageData = message.data() else { return }

        // Track this request so we can reply to it once APNs responds.
        pendingMessages.append(message)

        var options: UNAuthorizationOptions = [.alert, .badge, .sound]
        if data.provisional {
            options.insert(.provisional)
        }

        UNUserNotificationCenter.current().requestAuthorization(options: options) {
            [weak self] granted, error in
            guard let self else { return }

            if let error {
                // A genuine failure asking for authorization (rare). The user
                // never got to answer, so fall back to the current status.
                self.resolvePendingRequests(token: nil, error: error.localizedDescription)
                return
            }

            guard granted else {
                // The user denied the prompt. This isn't an error on iOS
                // (`granted == false`, `error == nil`); the denied status is
                // reported via the `permission` field.
                self.resolvePendingRequests(token: nil, error: nil)
                return
            }

            // Authorization granted. Ask APNs for a token; the outcome arrives
            // asynchronously via `.didReceiveDeviceToken` or
            // `.didFailToRegisterForRemoteNotifications`.
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    /// Replies to every pending request with the given token/error, tagging the
    /// reply with the *actual* current authorization status so the web side can
    /// tell "denied" apart from "granted but token retrieval failed".
    private nonisolated func resolvePendingRequests(token: String?, error: String?) {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            let permission = NotificationPermission(settings.authorizationStatus)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self else { return }
                    let data = RequestReplyData(
                        token: token,
                        permission: permission,
                        error: error
                    )
                    let messages = self.pendingMessages
                    self.pendingMessages.removeAll()
                    for message in messages {
                        self.reply(with: message.replacing(data: data))
                    }
                }
            }
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
        let token: String?
        let permission: NotificationPermission
        let error: String?
    }
}
