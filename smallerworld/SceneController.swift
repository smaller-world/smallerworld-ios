import HotwireNative
import SafariServices
import UIKit
import WebKit
import os.log

class SceneController: UIResponder {
  var window: UIWindow?

  private lazy var tabBarController = HotwireTabBarController(navigatorDelegate: self)
  private var targetURL: URL?

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
    Task {
      await InstallationID.shared.setDefaultCookie()
      await MainActor.run {
        loadTabs()
      }
    }
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
    if let window {
      window.rootViewController = tabBarController
    } else {
      fatalError("Window is not available.")
    }
  }

  /// Returns the next "step" URL toward `to`, based on the shared path prefix
  /// with `from`.
  ///
  /// Examples:
  /// - from: https://smallerworld.club/world
  ///   to:   https://smallerworld.club/world/friends
  ///   =>    https://smallerworld.club/world/friends
  /// - from: https://smallerworld.club/
  ///   to:   https://smallerworld.club/world/friends
  ///   =>    https://smallerworld.club/world
  /// - from: https://smallerworld.club/@kirsamansi
  ///   to:   https://smallerworld.club/world/friends
  ///   =>    https://smallerworld.club/world
  /// - from: nil
  ///   to:   https://smallerworld.club/world/friends
  ///   =>    https://smallerworld.club/world
  private func nextURL(from: URL?, to: URL) -> URL {
    let fromComponents = from?.pathComponents.filter { $0 != "/" } ?? []
    let toComponents = to.pathComponents.filter { $0 != "/" }
    guard !toComponents.isEmpty else { return to }

    var prefixCount = 0
    let maxPrefix = min(fromComponents.count, toComponents.count)
    while prefixCount < maxPrefix && fromComponents[prefixCount] == toComponents[prefixCount] {
      prefixCount += 1
    }

    let nextCount = min(prefixCount + 1, toComponents.count)
    if nextCount == toComponents.count {
      return to
    }

    let nextPath = "/" + toComponents.prefix(nextCount).joined(separator: "/")
    var components = URLComponents(url: to, resolvingAgainstBaseURL: false)
    components?.path = nextPath
    components?.query = nil
    components?.fragment = nil
    return components?.url ?? to
  }

  private func routeTowards(_ targetURL: URL) -> Bool {
    if targetURL.host() != SmallerWorld.baseURL.host() {
      let safariViewController = SFSafariViewController(url: targetURL)
      safariViewController.dismissButtonStyle = .close
      tabBarController.present(safariViewController, animated: true)
      return true
    }
    if let targetTab = HotwireTab.targetTab(for: targetURL),
      targetTab != currentTab() {
      switchToTab(targetTab)
    }
    let navigator = tabBarController.activeNavigator
    if let currentURL = navigator.activeWebView.url,
      currentURL == targetURL
    {
      return true
    }
    let nextURL = nextURL(from: navigator.activeWebView.url, to: targetURL)
    navigator.route(nextURL)
    return nextURL == targetURL
  }
}

extension SceneController: NavigatorDelegate {
  func handle(proposal: VisitProposal, from navigator: Navigator) -> ProposalResult {
    let targetTab = HotwireTab.targetTab(for: proposal.url)
    log(
      "handle",
      [
        "url": proposal.url.absoluteString,
        "targetTab": String(describing: targetTab?.title),
        "currentTab": currentTab().title,
      ])
    if let targetTab, targetTab != currentTab() {
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
    if let targetURL {
      if routeTowards(targetURL) {
        self.targetURL = nil
      }
    }
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
