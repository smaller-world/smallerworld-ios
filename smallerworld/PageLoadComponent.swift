import Foundation
import HotwireNative

extension Notification.Name {
    static let pageLoadComplete = Notification.Name("pageLoadComplete")
}

final class PageLoadComponent: BridgeComponent {
    override nonisolated class var name: String { "page-load" }

    override func onReceive(message: Message) {
        guard let event = Event(rawValue: message.event) else {
            return
        }

        switch event {
        case .connect:
            handleConnect()
        }
    }

    private func handleConnect() {
        NotificationCenter.default.post(name: .pageLoadComplete, object: nil)
    }
}

extension PageLoadComponent {
    fileprivate enum Event: String {
        case connect
    }
}
