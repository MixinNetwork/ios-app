import UIKit

struct ConversationExtensionSize: OptionSet {
    let rawValue: Int
    static let half = ConversationExtensionSize(rawValue: 1 << 0)
    static let full = ConversationExtensionSize(rawValue: 1 << 1)
}

enum ConversationExtensionContent {
    case viewController(UIViewController)
    case action(() -> Void)
    case url(URL)
}

protocol ConversationExtension {
    var icon: UIImage { get }
    var content: ConversationExtensionContent { get }
    var supportedSizes: ConversationExtensionSize { get }
}
