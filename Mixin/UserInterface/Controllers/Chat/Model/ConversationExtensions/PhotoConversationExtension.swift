import UIKit

class PhotoConversationExtension: ConversationExtension {
    
    var icon: UIImage {
        return UIImage(named: "Conversation/ic_camera")!
    }
    
    var content: ConversationExtensionContent {
        return .viewController(viewController)
    }
    
    var supportedSizes: ConversationExtensionSize {
        return .half
    }
    
    private let viewController = PhotoConversationExtensionViewController()
    
}
