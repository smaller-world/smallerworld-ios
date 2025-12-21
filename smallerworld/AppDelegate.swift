import UIKit
import HotwireNative
import BridgeComponents
import WebKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    let pathConfigurationUrl = URL(string: "https://smallerworld.club/path_configurations/ios_v1.json")!
    // let pathConfigurationUrl = URL(string: "https://37c16de776fd.ngrok-free.app/path_configurations/ios_v1.json")!

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        configureAppearance()
        configureHotwire()
        
        // Override point for customization after application launch.
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
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
            configuration.allowsInlineMediaPlayback = true
            let webView = WKWebView(frame: .zero, configuration: configuration)
            #if DEBUG
            webView.isInspectable = true
            #endif
            return webView
        }
        Hotwire.registerBridgeComponents(Bridgework.coreComponents)
        
        Hotwire.config.pathConfiguration.matchQueryStrings = false
        Hotwire.loadPathConfiguration(from: [ .server(pathConfigurationUrl) ])
        
        #if DEBUG
        Hotwire.config.debugLoggingEnabled = true
        #endif
    }
}

