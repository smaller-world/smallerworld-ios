import Foundation
import HotwireNative
import UIKit
import os

final class AppSettingsComponent: BridgeComponent {
    override nonisolated class var name: String { "app-settings" }

    override func onReceive(message: Message) {
        guard let event = Event(rawValue: message.event) else {
            return
        }

        switch event {
        case .open:
            handleOpen()
        }
    }

    private func handleOpen() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            Log.app.error("Failed to build app settings URL")
            return
        }

        UIApplication.shared.open(url)
    }
}

extension AppSettingsComponent {
    fileprivate enum Event: String {
        case open
    }
}
