import HotwireNative
import UIKit
import WebKit
import os.log

class SceneDelegate: UIResponder, UIWindowSceneDelegate, UNUserNotificationCenterDelegate {
  var window: UIWindow?

  private let navigator = Navigator(
    configuration: .init(
      name: "main",
      startLocation: AppConstants.rootURL,
    ))

  // Triggers from a cold start
  func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    UNUserNotificationCenter.current().delegate = self
    window?.rootViewController = navigator.rootViewController

    if let userActivity = connectionOptions.userActivities.first,
      userActivity.activityType == NSUserActivityTypeBrowsingWeb,
      let incomingURL = userActivity.webpageURL
    {
      navigator.route(incomingURL)
    } else if let response = connectionOptions.notificationResponse {
      handleNotificationTap(response.notification)
    } else {
      navigator.start()
    }

    // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
    // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
    // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
    // guard let _ = (scene as? UIWindowScene) else { return }
  }

  // Triggers when app is running in the background
  func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    if userActivity.activityType != NSUserActivityTypeBrowsingWeb {
      return
    }
    guard let incomingURL = userActivity.webpageURL else {
      return
    }
    navigator.route(incomingURL)
  }

  func sceneDidDisconnect(_ scene: UIScene) {
    // Called as the scene is being released by the system.
    // This occurs shortly after the scene enters the background, or when its session is discarded.
    // Release any resources associated with this scene that can be re-created the next time the scene connects.
    // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
  }

  func sceneDidBecomeActive(_ scene: UIScene) {
    // Called when the scene has moved from an inactive state to an active state.
    // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
  }

  func sceneWillResignActive(_ scene: UIScene) {
    // Called when the scene will move from an active state to an inactive state.
    // This may occur due to temporary interruptions (ex. an incoming phone call).
  }

  func sceneWillEnterForeground(_ scene: UIScene) {
    // Called as the scene transitions from the background to the foreground.
    // Use this method to undo the changes made on entering the background.
  }

  func sceneDidEnterBackground(_ scene: UIScene) {
    // Called as the scene transitions from the foreground to the background.
    // Use this method to save data, release shared resources, and store enough scene-specific state information
    // to restore the scene back to its current state.
  }

  // MARK: UNUserNotificationCenterDelegate

  // Show notifications even when app is in foreground
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
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
    handleNotificationTap(response.notification)
    completionHandler()
  }

  // MARK: Helpers

  private func subroutes(_ url: URL) -> [URL] {
    var pathComponents = url.pathComponents
    pathComponents.removeFirst()
    pathComponents.removeLast()
    guard !pathComponents.isEmpty else { return [url] }

    var result: [URL] = []
    var currentPath = ""

    for component in pathComponents {
      currentPath += "/" + component
      if let subroute = URL(string: currentPath, relativeTo: AppConstants.baseURL) {
        result.append(subroute)
      }
    }
    result.append(url)

    return result
  }

  private func handleNotificationTap(_ notification: UNNotification) {
    log("handleNotificationTap", ["notification": notification])

    let userInfo = notification.request.content.userInfo
    guard let targetString = userInfo["target_url"] as? String else { return }
    guard let targetUrl = URL(string: targetString, relativeTo: AppConstants.baseURL) else {
      return
    }

    if let activeUrl = navigator.activeWebView.url, activeUrl.path() == targetUrl.path() {
      logger.debug("Replacing active controller")
      // Currently on target route
      if activeUrl.query() != targetUrl.query() {
        navigator.route(targetUrl, options: VisitOptions(action: .replace))
      }
    } else {
      logger.debug("Clearing controllers and routing from root")
      // Target route is not active route
      navigator.clearAll(animated: true)
      for url in subroutes(targetUrl) {
        logger.debug("Routing to (sub)route: \(url)")
        navigator.route(url)
      }
    }
  }

  private func log(_ name: String, _ arguments: [String: Any] = [:]) {
    logger.debug("[SceneDelegate] \(name) \(arguments)")
  }

  // private func replaceOrRoute(_ url: URL) {
  //   if let currentUrl = navigator.activeWebView.url, currentUrl.path() == url.path() {
  //     if currentUrl.query() != url.query() {
  //       print("Replacing root view with: \(url)")
  //       navigator.route(url, options: VisitOptions(action: .replace))
  //     }
  //   } else {
  //     navigator.route(url)
  //   }
  // }
}

//extension SceneDelegate: VisitableDelegate {
//    visidid
//}
