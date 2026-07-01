import BridgeComponents
import HotwireNative
import UIKit
import UserNotifications
import WebKit
import os.log

let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: "smallerworld"
)

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        styleApplication()
        configureHotwire()

        // Override point for customization after application launch.
        return true
    }

    // MARK: Push Notifications

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        NotificationCenter.default.post(name: .didReceiveDeviceToken, object: tokenString)
    }

    func application(
        _ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        logger.error("Failed to register for remote notifications: \(error, privacy: .public)")
    }

    // MARK: UISceneSession Lifecycle

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
    }

    func application(
        _ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>
    ) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

    // MARK: Helpers

    private func styleApplication() {
        UINavigationBar.appearance().standardAppearance = AppUI.navigationBarAppearance()
        UITabBar.appearance().standardAppearance = AppUI.tabBarAppearance()
    }

    private func configureHotwire() {
        Hotwire.config.applicationUserAgentPrefix = SmallerWorld.userAgentPrefix
        Hotwire.config.defaultViewController = { url in
            WebViewController(url: url)
        }
        Hotwire.config.makeCustomWebView = { configuration in
            // For background videos
            configuration.allowsInlineMediaPlayback = true
            let webView = WKWebView(frame: .zero, configuration: configuration)
            #if DEBUG
                webView.isInspectable = true
            #endif
            return webView
        }
        Hotwire.config.animateReplaceActions = true

        // == Bridge components
        var components = Bridgework.coreComponents
        components.append(NotificationPermissionComponent.self)
        components.append(NotificationTokenComponent.self)
        components.append(PassesComponent.self)
        components.append(PassComponent.self)
        components.append(PageLoadComponent.self)
        components.append(NotificationBadgeCountComponent.self)
        Hotwire.registerBridgeComponents(components)

        // == Path configuration
        Hotwire.config.pathConfiguration.matchQueryStrings = false
        Hotwire.loadPathConfiguration(from: [
            .file(Bundle.main.url(forResource: "path-configuration", withExtension: "json")!),
            .server(SmallerWorld.pathConfigurationURL),
        ])

        // == Debugging
        #if DEBUG
            Hotwire.config.debugLoggingEnabled = true
        #endif
    }
}
