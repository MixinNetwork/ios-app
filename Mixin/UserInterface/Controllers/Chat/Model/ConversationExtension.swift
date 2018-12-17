import UIKit

struct ConversationExtensionSize: OptionSet {
    let rawValue: Int
    static let half = ConversationExtensionSize(rawValue: 1 << 0)
    static let full = ConversationExtensionSize(rawValue: 1 << 1)
}

enum ConversationExtensionContent {
    case embed(UIViewController)
    case present(UIViewController)
    case action(() -> Void)
    case url(URL)
}

protocol ConversationExtension: class {
    var conversationId: String! { get set }
    var icon: UIImage { get }
    var content: ConversationExtensionContent { get }
    var supportedSizes: ConversationExtensionSize { get }
}

enum FixedConversationExtension {
    case photo
    case file
    case transfer
    case contact
    case call
    
    var image: UIImage {
        switch self {
        case .photo:
            return UIImage(named: "Conversation/ic_camera")!
        case .file:
            return #imageLiteral(resourceName: "ic_conversation_file")
        case .transfer:
            return UIImage(named: "Conversation/ic_transfer")!
        case .contact:
            return #imageLiteral(resourceName: "ic_conversation_contact")
        case .call:
            return UIImage(named: "Conversation/ic_call")!
        }
    }
    
}
