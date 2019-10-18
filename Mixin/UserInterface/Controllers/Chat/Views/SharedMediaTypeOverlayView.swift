import UIKit

class SharedMediaTypeOverlayView: MediaTypeOverlayView {
    
    override class var backgroundImage: UIImage? {
        return R.image.conversation.bg_shared_media_bottom_shadow()
    }
    
}
