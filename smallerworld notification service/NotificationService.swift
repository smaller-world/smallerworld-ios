import Intents
import UserNotifications

class NotificationService: UNNotificationServiceExtension {
  var contentHandler: ((UNNotificationContent) -> Void)?
  var content: UNMutableNotificationContent?

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
  ) {
    self.contentHandler = contentHandler
    self.content = (request.content.mutableCopy() as? UNMutableNotificationContent)
    guard let content else { return }

    // If there's no icon URL, fall back to a standard notification (no
    // communication intent).
    guard
      let iconUrlString = content.userInfo["icon_url"] as? String,
      let iconUrl = URL(string: iconUrlString, relativeTo: AppConstants.baseURL)
    else {
      contentHandler(content)
      return
    }

    // Download the sender icon
    let task = URLSession.shared.downloadTask(with: iconUrl) {
      [weak self] (location, response, error) in
      guard let self = self, let imageURI = location,
        let imageData = try? Data(contentsOf: imageURI)
      else {
        contentHandler(content)
        return
      }
      self.applyCommunicationIntent(imageData: imageData, )
    }
    task.resume()
  }

  private func applyCommunicationIntent(imageData: Data) {
    guard let content = content, let contentHandler = contentHandler else { return }

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
      // Wrap the notification in the Communication intent
      if let updatedContent = try? content.updating(from: intent) {
        contentHandler(updatedContent)
      } else {
        contentHandler(content)
      }
    }
  }

  override func serviceExtensionTimeWillExpire() {
    if let content = content, let contentHandler = contentHandler {
      contentHandler(content)
    }
  }
}
