import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    private let coordinator = RouteCoordinator()

    // MARK: UIWindowSceneDelegate

    // Triggers from a cold start
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let window else { return }
        window.rootViewController = coordinator.rootViewController
        coordinator.installLaunchOverlay(over: window)
        coordinator.prepareColdStart(connectionOptions)

        Task {
            await DeviceIdentifier.shared.setDefaultCookie()
            await MainActor.run {
                UNUserNotificationCenter.current().delegate = coordinator
                coordinator.start()
            }
        }
    }

    // Triggers when app is running in the background
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        coordinator.continueUserActivity(userActivity)
    }

    //  func sceneDidDisconnect(_ scene: UIScene) {}
    //  func sceneDidBecomeActive(_ scene: UIScene) {}
    //  func sceneWillResignActive(_ scene: UIScene) {}
    //  func sceneWillEnterForeground(_ scene: UIScene) {}
    //  func sceneDidEnterBackground(_ scene: UIScene) {}
}
