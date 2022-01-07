import UIKit
import SDWebImage

class AppLoadingIndicatorView: SDAnimatedImageView {
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        loadImage()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadImage()
    }
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: 46, height: 54)
    }
    
    private func loadImage() {
        let scaleSuffix: String
        if UIScreen.main.scale == 3 {
            scaleSuffix = "@3x"
        } else {
            scaleSuffix = "@2x"
        }
        let filename = "ic_app_loading" + scaleSuffix
        guard let url = Bundle.main.url(forResource: filename, withExtension: "webp") else {
            return
        }
        guard let data = try? Data(contentsOf: url) else {
            return
        }
        self.image = SDAnimatedImage(data: data, scale: UIScreen.main.scale)
    }
    
}
