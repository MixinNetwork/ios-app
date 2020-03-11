import UIKit

class RenderingModeSwitchableImageView: UIImageView {
    
    var renderingMode: UIImage.RenderingMode = .automatic
    
    override var image: UIImage? {
        get {
            super.image
        }
        set {
            super.image = newValue?.withRenderingMode(renderingMode)
        }
    }
    
}
