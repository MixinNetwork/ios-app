import UIKit

final class GalleryVideoSlider: UISlider {
    
    private let trackHeight: CGFloat = 4
    private let hitTestAreaHeight: CGFloat = 44
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    override func trackRect(forBounds bounds: CGRect) -> CGRect {
        return CGRect(x: 0, y: (bounds.height - trackHeight) / 2, width: bounds.width, height: trackHeight)
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let hitTestBounds = CGRect(x: bounds.origin.x,
                                   y: bounds.origin.y - (hitTestAreaHeight - bounds.height) / 2,
                                   width: bounds.width,
                                   height: hitTestAreaHeight)
        return hitTestBounds.contains(point)
    }
    
    private func prepare() {
        setThumbImage(R.image.ic_slider_thumb()!, for: .normal)
        setThumbImage(R.image.ic_slider_thumb()!, for: .highlighted)
    }
    
}
