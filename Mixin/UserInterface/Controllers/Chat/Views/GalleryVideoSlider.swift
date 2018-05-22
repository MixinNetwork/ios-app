import UIKit

class GalleryVideoSlider: UISlider {

    let trackHeight: CGFloat = 4
    
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

    private func prepare() {
        setThumbImage(#imageLiteral(resourceName: "ic_slider_thumb"), for: .normal)
        setThumbImage(#imageLiteral(resourceName: "ic_slider_thumb"), for: .highlighted)
    }
    
}
