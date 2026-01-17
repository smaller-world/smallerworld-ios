import HotwireNative
import UIKit
import WebKit
import os.log

class SceneController: UIResponder {
  var window: UIWindow?

  //  private var navigationTrackers: [HotwireTab: NavigationTracker] = [:]
  private lazy var tabBarController = HotwireTabBarController(navigatorDelegate: self)
  private var targetURL: URL?

  //  private var rootViewController: UIViewController {
  //    guard let window else {
  //      fatalError("Uninitialized window.")
  //    }
  //    guard let controller = window.rootViewController else {
  //      fatalError("Window is missing root view controller.")
  //    }
  //    return controller
  //  }

  private func log(_ name: String, _ arguments: [String: Any] = [:]) {
    logger.debug("[SceneController] \(name) \(arguments)")
  }

  private func switchToTab(_ tab: HotwireTab) {
    guard let tabIndex = HotwireTab.all.firstIndex(of: tab) else {
      return
    }
    tabBarController.selectedIndex = tabIndex
  }

  private func currentTab() -> HotwireTab {
    HotwireTab.all[tabBarController.selectedIndex]
  }

  private func promptForAuthentication() {
    let loginURL = SmallerWorld.baseURL.appendingPathComponent("/login")
    tabBarController.activeNavigator.route(loginURL)
    // Do nothing if login navigator is set
    //    if loginNavigator != nil {
    //      return
    //    }
    //    let navigator = buildLoginNavigator()
    //    self.loginNavigator = navigator
    //    rootViewController.present(navigator.rootViewController, animated: true) {
    //      navigator.start()
    //    }
  }

  // TODO: Make this actually work? Not seeing the correct fonts being rendered right now.
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
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    configureNotificationCenterDelegate()
    configureTabBarControllerDelegate()
    configureAppearance()
    if let userActivity = connectionOptions.userActivities.first,
      userActivity.activityType == NSUserActivityTypeBrowsingWeb,
      let incomingURL = userActivity.webpageURL
    {
      targetURL = incomingURL
    } else if let response = connectionOptions.notificationResponse {
      handleNotificationTap(response.notification)
    }
    loadTabs()
  }

  // Triggers when app is running in the background
  func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    if userActivity.activityType != NSUserActivityTypeBrowsingWeb {
      return
    }
    if let incomingURL = userActivity.webpageURL {
      targetURL = incomingURL
    }
  }

  //  func sceneDidDisconnect(_ scene: UIScene) {}
  //  func sceneDidBecomeActive(_ scene: UIScene) {}
  //  func sceneWillResignActive(_ scene: UIScene) {}
  //  func sceneWillEnterForeground(_ scene: UIScene) {}
  //  func sceneDidEnterBackground(_ scene: UIScene) {}

  // MARK: Helpers

  private func loadTabs() {
    tabBarController.load(HotwireTab.all)
    window!.rootViewController = tabBarController
  }

  //  private func subRoutes(_ url: URL) -> [URL] {
  //    var pathComponents = url.pathComponents
  //    pathComponents.removeFirst()
  //    pathComponents.removeLast()
  //    guard !pathComponents.isEmpty else { return [url] }
  //
  //    var result: [URL] = []
  //    var currentPath = ""
  //
  //    for component in pathComponents {
  //      currentPath += "/" + component
  //      if let subroute = URL(string: currentPath, relativeTo: SmallerWorld.baseURL) {
  //        result.append(subroute)
  //      }
  //    }
  //    result.append(url)
  //
  //    return result
  //  }

  //  @MainActor
  //  private func deepRouteTo(_ url: URL) async {
  //    log("deepRouteTo", ["url": url])
  //
  //    let targetTab = HotwireTab.targetTab(for: url)
  //    let tabTracker = navigationTracker(for: targetTab)
  //
  //    // Wait for current navigation in target tab
  //    if tabTracker.isNavigating {
  //      let navigationSucceeded = await tabTracker.waitForCurrentRequestToFinish()
  //      if !navigationSucceeded {
  //        return
  //      }
  //    }
  //
  //    // Switch to target tab first
  //    switchToTab(targetTab)
  //
  //    // Now use activeNavigator (which is the target tab's navigator)
  //    let navigator = tabBarController.activeNavigator
  //
  //    // If already on route, simply replace it
  //    if let activeUrl = navigator.activeWebView.url, url.path() == activeUrl.path() {
  //      if activeUrl.query() != url.query() {
  //        logger.debug("Replacing top-level controller with new route")
  //        navigator.route(url, options: VisitOptions(action: .replace))
  //      } else {
  //        logger.debug("Already navigated to desired URL")
  //      }
  //      return
  //    }
  //
  //    // Otherwise clear all controllers and route from root
  //    logger.debug("Clearing tab stack and routing from root")
  //    navigator.clearAll()
  //    for subroute in subRoutes(url) {
  //      logger.debug("Routing to (sub)route: \(subroute)")
  //      await tabTracker.waitForCurrentRequestToFinish()
  //      if let activeUrl = navigator.activeWebView.url, activeUrl.path() != subroute.path() {
  //        navigator.route(subroute)
  //      }
  //    }
  //  }
}

extension SceneController: NavigatorDelegate {
  func handle(proposal: VisitProposal, from navigator: Navigator) -> ProposalResult {
    log(
      "handle",
      [
        "url": proposal.url.absoluteString,
        "targetTab": HotwireTab.targetTab(for: proposal.url).title,
        "currentTab": currentTab().title,
      ])
    let targetTab = HotwireTab.targetTab(for: proposal.url)
    if targetTab != currentTab() {
      logger.debug("Received navigation proposal for tab (\(targetTab.title)), switching...")
      switchToTab(targetTab)
      tabBarController.activeNavigator.route(proposal.url)
      return .reject
    }
    return .accept
  }

  // TODO: Deep route if targetURL is set.
  func requestDidFinish(at url: URL) {
    log("requestDidFinish", ["url": url])
  }

  func visitableDidFailRequest(
    _ visitable: Visitable,
    error: Error,
    retryHandler: RetryBlock?
  ) {
    log("visitableDidFailRequest", ["error": error])
    if let turboError = error as? TurboError, case .http(let statusCode) = turboError,
      statusCode == 401
    {
      logger.debug("Got 401 status code; prompting for authentication...")
      promptForAuthentication()
    } else if let errorPresenter = visitable as? ErrorPresenter {
      errorPresenter.presentError(error, retryHandler: retryHandler)
    }
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
    handleNotificationTap(response.notification)
    completionHandler()
  }

  // MARK: Helpers

  private func configureNotificationCenterDelegate() {
    UNUserNotificationCenter.current().delegate = self
  }

  private func handleNotificationTap(_ notification: UNNotification) {
    log("handleNotificationTap", ["notification": notification])
    let userInfo = notification.request.content.userInfo
    guard let targetString = userInfo["target_url"] as? String else {
      return
    }
    if let targetUrl = URL(string: targetString, relativeTo: SmallerWorld.baseURL) {
      self.targetURL = targetUrl
    }
  }
}

extension SceneController: UITabBarControllerDelegate {
  public func tabBarController(
    _ tabBarController: UITabBarController, didSelect viewController: UIViewController
  ) {
    let navigator = self.tabBarController.activeNavigator
    if navigator.rootViewController.viewControllers.isEmpty,
      navigator.modalRootViewController.viewControllers.isEmpty
    {
      navigator.start()
    } else if navigator.activeWebView.isHidden && !navigator.activeWebView.isLoading {
      navigator.reload()
    }
  }

  // MARK: Helpers

  private func configureTabBarControllerDelegate() {
    tabBarController.delegate = self
  }
}
