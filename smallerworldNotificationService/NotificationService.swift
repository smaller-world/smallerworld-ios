import Intents
import UserNotifications
import os

private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: "smallerworld"
)

class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var content: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        self.content = (request.content.mutableCopy() as? UNMutableNotificationContent)
        guard let content else {
            logger.error("Failed to create mutable content copy; delivering original")
            contentHandler(request.content)
            return
        }

        // If there's no icon URL, fall back to a standard notification (no
        // communication intent).
        guard
            let iconUrlString = content.userInfo["icon_url"] as? String,
            let iconUrl = URL(string: iconUrlString, relativeTo: SmallerWorld.baseURL)
        else {
            logger.log("No icon_url in payload; delivering standard notification")
            contentHandler(content)
            return
        }
        logger.log("Downloading sender icon from \(iconUrl.absoluteString, privacy: .public)")

        // Download the sender icon
        let task = URLSession.shared.downloadTask(with: iconUrl) {
            [weak self] (location, response, error) in
            if let error {
                logger.error(
                    "Icon download failed: \(error.localizedDescription, privacy: .public)")
            }
            if let http = response as? HTTPURLResponse {
                logger.log("Icon download response status: \(http.statusCode, privacy: .public)")
            }
            guard let self = self, let imageURI = location,
                let imageData = try? Data(contentsOf: imageURI)
            else {
                logger.error("No image data; delivering standard notification")
                contentHandler(content)
                return
            }
            logger.log(
                "Downloaded \(imageData.count, privacy: .public) bytes; applying communication intent"
            )
            self.applyCommunicationIntent(imageData: imageData)
        }
        task.resume()
    }

    private func applyCommunicationIntent(imageData: Data) {
        guard let content = content, let contentHandler = contentHandler else {
            logger.error("Missing content or contentHandler in applyCommunicationIntent")
            return
        }

        // Create the Sender object
        let sender = INPerson(
            personHandle: INPersonHandle(value: content.threadIdentifier, type: .unknown),
            nameComponents: nil,
            displayName: content.title,
            image: INImage(imageData: imageData),
            contactIdentifier: nil,
            customIdentifier: content.threadIdentifier,
        )

        // Create the Intent
        let intent = INSendMessageIntent(
            recipients: nil,
            outgoingMessageType: .outgoingMessageText,
            content: content.body,
            speakableGroupName: nil,
            conversationIdentifier: content.threadIdentifier,
            serviceName: nil,
            sender: sender,
            attachments: nil
        )

        let interaction = INInteraction(intent: intent, response: nil)
        interaction.direction = .incoming
        interaction.donate { error in
            if let error {
                logger.error(
                    "Intent donation failed: \(error.localizedDescription, privacy: .public)")
            }
            // Wrap the notification in the Communication intent
            if let updatedContent = try? content.updating(from: intent) {
                logger.log("Delivering communication notification with sender icon")
                contentHandler(updatedContent)
            } else {
                logger.error("content.updating(from:) failed; delivering standard notification")
                contentHandler(content)
            }
        }
    }

    override func serviceExtensionTimeWillExpire() {
        logger.error("serviceExtensionTimeWillExpire; delivering best-effort content")
        if let content = content, let contentHandler = contentHandler {
            contentHandler(content)
        }
    }
}
