import Foundation
import HotwireNative

extension Notification.Name {
    static let pageLoadComplete = Notification.Name("pageLoadComplete")
}

final class PageLoadComponent: BridgeComponent {
    override nonisolated class var name: String { "page-load" }

    override func onReceive(message: Message) {
        guard message.event == "connect" else { return }
        NotificationCenter.default.post(name: .pageLoadComplete, object: nil)
    }
}
