import BridgeComponents
import HotwireNative
import UIKit
import UserNotifications
import WebKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
  #if DEBUG
    static let rootURL = URL(string: "https://kaibook.itskai.me/start/app")!
  #else
    static let rootURL = URL(string: "https://smallerworld.club/start/app")!
  #endif
  let pathConfigurationUrl = URL(
    string: "https://smallerworld.club/path_configurations/ios_v1.json")!

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    configureAppearance()
    configureHotwire()

    // Override point for customization after application launch.
    return true
  }

  // MARK: Push Notifications

  func application(
    _ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    NotificationCenter.default.post(name: .didReceiveDeviceToken, object: deviceToken)
  }

  func application(
    _ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("Failed to register for remote notifications: \(error)")
  }
  // let pathConfigurationUrl = URL(string: "https://37c16de776fd.ngrok-free.app/path_configurations/ios_v1.json")!

  // MARK: UISceneSession Lifecycle

  func application(
    _ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    // Called when a new scene session is being created.
    // Use this method to select a configuration to create the new scene with.
    return UISceneConfiguration(
      name: "Default Configuration", sessionRole: connectingSceneSession.role)
  }

  func application(
    _ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>
  ) {
    // Called when the user discards a scene session.
    // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
    // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
  }

  // == Helpers ==

  private func configureAppearance() {
    //        let navbar = UINavigationBar.appearance()
    //        navbar.titleTextAttributes = [.foregroundColor: UIColor.black]
  }

  private func configureHotwire() {
    Hotwire.config.defaultViewController = { url in
      WebViewController(url: url)
    }
    Hotwire.config.makeCustomWebView = { configuration in
      // For background videos
      configuration.allowsInlineMediaPlayback = true
      let webView = WKWebView(frame: .zero, configuration: configuration)
      InstallationID.current.setCookie(webView: webView)
      #if DEBUG
        webView.isInspectable = true
      #endif
      return webView
    }

    // == Bridge components
    var components = Bridgework.coreComponents
    components.append(NotificationPermissionComponent.self)
    components.append(NotificationTokenComponent.self)
    Hotwire.registerBridgeComponents(components)

    // == Path configuration
    Hotwire.config.pathConfiguration.matchQueryStrings = false
    Hotwire.loadPathConfiguration(from: [.server(pathConfigurationUrl)])

    // == Debugging
    #if DEBUG
      Hotwire.config.debugLoggingEnabled = true
    #endif
  }
}
