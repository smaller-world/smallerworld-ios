import Foundation
import UserNotifications

extension RouteCoordinator: UNUserNotificationCenterDelegate {
    // Show notifications even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler:
            @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner even in foreground
        completionHandler([.banner, .sound])
    }

    // Handle notification interaction
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let targetURL = notificationTargetURL(response.notification) {
            self.targetURL = targetURL
            routeTowardsTargetURL()
        }
        completionHandler()
    }
}
