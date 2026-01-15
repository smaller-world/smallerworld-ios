import HotwireNative
import UIKit
import WebKit
import os.log

class SceneController: UIResponder {
  var window: UIWindow?

  private var navigationTrackers: [String: NavigationTracker] = [:]
  private lazy var tabBarController = HotwireTabBarController(navigatorDelegate: self)

  private func log(_ name: String, _ arguments: [String: Any] = [:]) {
    logger.debug("[SceneController] \(name) \(arguments)")
  }

  private func navigationTracker(for tab: HotwireTab) -> NavigationTracker {
    if let existing = navigationTrackers[tab.url.path()] {
      return existing
    }
    let tracker = NavigationTracker(name: tab.url.path())
    navigationTrackers[tab.url.path()] = tracker
    if navigationTrackers.count > HotwireTab.all.count {
      fatalError("Navigation tracker count exceeds configured tabs.")
    }
    return tracker
  }

  private func switchToTab(_ tab: HotwireTab) {
    if let index = HotwireTab.all.firstIndex(of: tab) {
      tabBarController.selectedIndex = index
    }
  }

  private func currentTab() -> HotwireTab {
    HotwireTab.all[tabBarController.selectedIndex]
  }

  private func promptForAuthentication() {
    let authURL = SmallerWorld.baseURL.appendingPathComponent("/login")
    tabBarController.activeNavigator.route(authURL)
  }

  private func configureAppearance() {
    let label = UILabel.appearance()
    label.font = .appBody()
    label.adjustsFontForContentSizeCategory = true

    // TODO: This customization didn't seem to work...
    let tabBarItem = UITabBarItem.appearance()
    tabBarItem.setTitleTextAttributes(
      [.font: UIFont.appHeading(textStyle: .caption1)], for: .normal)
    tabBarItem.setTitleTextAttributes(
      [.font: UIFont.appHeading(textStyle: .caption1)], for: .selected)
  }
}

extension SceneController: UIWindowSceneDelegate {
  // Triggers from a cold start
  func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    configureAppearance()
    configureNotificationCenterDelegate()
    configureTabBarDelegate()
    setRootControllerAndRoute(connectionOptions)
  }

  // Triggers when app is running in the background
  func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    if userActivity.activityType != NSUserActivityTypeBrowsingWeb {
      return
    }
    if let incomingURL = userActivity.webpageURL {
      Task {
        await deepRouteTo(incomingURL)
      }
    }
  }

  func sceneDidDisconnect(_ scene: UIScene) {}
  func sceneDidBecomeActive(_ scene: UIScene) {}
  func sceneWillResignActive(_ scene: UIScene) {}
  func sceneWillEnterForeground(_ scene: UIScene) {}
  func sceneDidEnterBackground(_ scene: UIScene) {}

  // MARK: Helpers

  private func setRootControllerAndRoute(_ connectionOptions: UIScene.ConnectionOptions) {
    guard let window else { return }
    window.rootViewController = tabBarController
    Task { [weak self] in
      guard let self else { return }
      await InstallationID.shared.setDefaultCookie()
      await MainActor.run {
        self.tabBarController.load(HotwireTab.all)
      }
      if let userActivity = connectionOptions.userActivities.first,
        userActivity.activityType == NSUserActivityTypeBrowsingWeb,
        let incomingURL = userActivity.webpageURL
      {
        await self.deepRouteTo(incomingURL)
      } else if let response = connectionOptions.notificationResponse {
        await self.handleNotificationTap(response.notification)
      }
    }
  }

  private func subRoutes(_ url: URL) -> [URL] {
    var pathComponents = url.pathComponents
    pathComponents.removeFirst()
    pathComponents.removeLast()
    guard !pathComponents.isEmpty else { return [url] }

    var result: [URL] = []
    var currentPath = ""

    for component in pathComponents {
      currentPath += "/" + component
      if let subroute = URL(string: currentPath, relativeTo: SmallerWorld.baseURL) {
        result.append(subroute)
      }
    }
    result.append(url)

    return result
  }

  @MainActor
  private func deepRouteTo(_ url: URL) async {
    log("deepRouteTo", ["url": url])

    let targetTab = HotwireTab.targetTab(for: url)
    let tracker = navigationTracker(for: targetTab)

    // Wait for current navigation in target tab
    if tracker.isNavigating {
      let navigationSucceeded = await tracker.waitForCurrentRequestToFinish()
      if !navigationSucceeded {
        return
      }
    }

    // Switch to target tab first
    switchToTab(targetTab)

    // Now use activeNavigator (which is the target tab's navigator)
    let navigator = tabBarController.activeNavigator

    // If already on route, simply replace it
    if let activeUrl = navigator.activeWebView.url, url.path() == activeUrl.path() {
      if activeUrl.query() != url.query() {
        logger.debug("Replacing top-level controller with new route")
        navigator.route(url, options: VisitOptions(action: .replace))
      } else {
        logger.debug("Already navigated to desired URL")
      }
      return
    }

    // Otherwise clear all controllers and route from root
    logger.debug("Clearing tab stack and routing from root")
    navigator.clearAll()
    for subroute in subRoutes(url) {
      logger.debug("Routing to (sub)route: \(subroute)")
      let navigationSucceeded = await tracker.waitForCurrentRequestToFinish()
      if !navigationSucceeded {
        return
      }
      if let activeUrl = navigator.activeWebView.url, activeUrl.path() != subroute.path() {
        navigator.route(subroute)
      }
    }
  }
}

extension SceneController: NavigatorDelegate {
  func handle(proposal: VisitProposal, from navigator: Navigator) -> ProposalResult {
    let targetTab = HotwireTab.targetTab(for: proposal.url)
    if targetTab != currentTab() {
      logger.debug("Received navigation proposal for tab [\(targetTab.url.path())], switching...")
      switchToTab(targetTab)
      tabBarController.activeNavigator.route(proposal.url)
      return .reject
    }

    let tracker = navigationTracker(for: targetTab)
    tracker.visitStarted()
    return .accept
  }

  func requestDidFinish(at url: URL) {
    let targetTab = HotwireTab.targetTab(for: url)
    log("requestDidFinish", ["url": url, "targetTab": targetTab.url.path()])
    let tracker = navigationTracker(for: targetTab)
    tracker.visitEnded()
  }

  func visitableDidFailRequest(
    _ visitable: Visitable,
    error: Error,
    retryHandler: RetryBlock?
  ) {
    log("visitableDidFailRequest", ["error": error])

    let url = visitable.initialVisitableURL
    let targetTab = HotwireTab.targetTab(for: url)
    let tracker = navigationTracker(for: targetTab)
    tracker.visitEnded(success: false)

    if let turboError = error as? TurboError, case .http(let statusCode) = turboError,
      statusCode == 401
    {
      logger.debug("Got 401 status code; prompting for authentication...")
      promptForAuthentication()
    } else if let errorPresenter = visitable as? ErrorPresenter {
      errorPresenter.presentError(error) {
        retryHandler?()
      }
    } else {
      let alert = UIAlertController(
        title: "an error occurred", message: error.localizedDescription, preferredStyle: .alert)
      alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
      tabBarController.activeNavigator.present(alert, animated: true)
    }
  }
}

extension SceneController: UITabBarControllerDelegate {
  func tabBarController(
    _ tabBarController: UITabBarController, didSelect viewController: UIViewController
  ) {
    let selectedTab = HotwireTab.all[tabBarController.selectedIndex]
    let tracker = navigationTracker(for: selectedTab)
    logger.debug("Tab [\(selectedTab.url.path())] selected, tracker: \(tracker)")
    if tracker.isNavigating || tracker.lastNavigationSuccess {
      return
    }
    if let controller = tabBarController as? HotwireTabBarController {
      logger.debug("Reloading tab [\(selectedTab.url.path())]")
      controller.activeNavigator.reload()
    }
  }

  // MARK: Helpers

  private func configureTabBarDelegate() {
    tabBarController.delegate = self
  }
}

extension SceneController: UNUserNotificationCenterDelegate {
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
    Task {
      await handleNotificationTap(response.notification)
      completionHandler()
    }
  }

  // MARK: Helpers

  private func configureNotificationCenterDelegate() {
    UNUserNotificationCenter.current().delegate = self
  }

  @MainActor
  private func handleNotificationTap(_ notification: UNNotification) async {
    log("handleNotificationTap", ["notification": notification])
    let userInfo = notification.request.content.userInfo
    guard let targetString = userInfo["target_url"] as? String else { return }
    guard let targetUrl = URL(string: targetString, relativeTo: SmallerWorld.baseURL) else {
      return
    }
    await deepRouteTo(targetUrl)
  }
}
