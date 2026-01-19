import HotwireNative
import UIKit

extension HotwireTab {
  static let all: [HotwireTab] = [.world, .universe, .spaces]

  static let world = HotwireTab(
    title: "your world",
    image: UIImage(systemName: "person.crop.square.fill")!,
    url: SmallerWorld.baseURL.appendingPathComponent("/world")
  )

  static let universe = HotwireTab(
    title: "universe",
    image: UIImage(systemName: "square.grid.2x2.fill")!,
    url: SmallerWorld.baseURL.appendingPathComponent("/universe")
  )

  static let spaces = HotwireTab(
    title: "spaces",
    image: UIImage(systemName: "person.2.crop.square.stack.fill")!,
    url: SmallerWorld.baseURL.appendingPathComponent("/spaces")
  )

  /// Get the tab that should handle a given URL based on path prefix.
  static func targetTab(for url: URL) -> HotwireTab? {
    let path = url.path()
    if path.hasPrefix("/universe") {
      return .universe
    }
    if path.hasPrefix("/spaces") {
      return .spaces
    }
    if path.hasPrefix("/world") {
      return .world
    }
    return nil
  }
}
