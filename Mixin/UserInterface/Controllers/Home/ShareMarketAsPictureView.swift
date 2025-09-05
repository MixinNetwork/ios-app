import UIKit

final class ShareMarketAsPictureView: UIView {
    
    // Manipulating UIImage to render on CGContext is quite cumbersome, and the behavior varies
    // across different iOS versions. Therefore, an invisible view is used to capture a screenshot
    // to generate the image for sharing.
    
    @IBOutlet weak var screenshotWrapperView: UIView!
    @IBOutlet weak var screenshotImageView: UIImageView!
    @IBOutlet weak var displayImageView: UIImageView!
    
    func setImage(_ image: UIImage) {
        let ratio = image.size.width / image.size.height
        screenshotImageView.image = image
        screenshotImageView.snp.makeConstraints { make in
            make.width.equalTo(screenshotImageView.snp.height).multipliedBy(ratio)
        }
        displayImageView.image = image
        displayImageView.snp.remakeConstraints { make in
            make.width.equalTo(displayImageView.snp.height).multipliedBy(ratio).priority(.low)
        }
    }
    
}
