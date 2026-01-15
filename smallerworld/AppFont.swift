import UIKit

enum AppFont {
  static let heading = "Bricolage Grotesque"
  static let body = "Manrope"
}

extension UIFont {
  static func appHeading(textStyle: UIFont.TextStyle = .title1) -> UIFont {
    let baseFont = UIFont(name: AppFont.heading, size: 20)!
    return UIFontMetrics(forTextStyle: textStyle)
      .scaledFont(for: baseFont)
  }

  static func appBody(textStyle: UIFont.TextStyle = .body) -> UIFont {
    let baseFont = UIFont(name: AppFont.body, size: 16)!
    return UIFontMetrics(forTextStyle: textStyle)
      .scaledFont(for: baseFont)
  }
}
