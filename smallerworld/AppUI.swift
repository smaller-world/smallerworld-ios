import UIKit

class AppUI {
    static func navigationBarAppearance() -> UINavigationBarAppearance {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        if let font = UIFont(name: AppFont.headingSemiBold, size: 17),
            let largeFont = UIFont(name: AppFont.headingBold, size: 34)
        {
            appearance.titleTextAttributes[.font] = font
            appearance.largeTitleTextAttributes[.font] = largeFont
        }
        return appearance
    }
    
    static func tabBarAppearance() -> UITabBarAppearance {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        if let font = UIFont(name: AppFont.headingMedium, size: 10) {
            appearance.stackedLayoutAppearance.normal.titleTextAttributes[.font] = font
            appearance.stackedLayoutAppearance.selected.titleTextAttributes[.font] = font
        }
        return appearance
    }
}
