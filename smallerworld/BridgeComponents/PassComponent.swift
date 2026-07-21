import Foundation
import HotwireNative
import PassKit
import UIKit

final class PassComponent: BridgeComponent {
    override nonisolated class var name: String { "pass" }

    override func onReceive(message: Message) {
        guard let event = Event(rawValue: message.event) else {
            return
        }

        switch event {
        case .open:
            handleOpen(message: message)
        }
    }

    private func handleOpen(message: Message) {
        guard let data: OpenMessageData = message.data() else { return }

        let library = PKPassLibrary()
        guard
            let pass = library.pass(
                withPassTypeIdentifier: data.passTypeIdentifier,
                serialNumber: data.serialNumber
            ),
            let url = pass.passURL
        else {
            return
        }

        UIApplication.shared.open(url)
    }
}

extension PassComponent {
    fileprivate enum Event: String {
        case open
    }

    fileprivate struct OpenMessageData: Decodable {
        let passTypeIdentifier: String
        let serialNumber: String
    }
}
