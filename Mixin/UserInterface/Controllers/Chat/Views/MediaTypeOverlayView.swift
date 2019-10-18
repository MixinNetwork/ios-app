import UIKit

class MediaTypeOverlayView: UIView, XibDesignable {
    
    enum Style {
        case video(duration: TimeInterval)
        case gif
        case hidden
    }
    
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var gifFileTypeView: UILabel!
    @IBOutlet weak var videoTypeView: UIStackView!
    @IBOutlet weak var videoDurationLabel: UILabel!
    
    class var backgroundImage: UIImage? {
        return R.image.conversation.bg_photo_bottom_shadow()
    }
    
    var nibName: String {
        return "MediaTypeOverlayView"
    }
    
    var style: Style = .hidden {
        didSet {
            updateAppearance()
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadXib()
        backgroundImageView.image = type(of: self).backgroundImage
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadXib()
        backgroundImageView.image = type(of: self).backgroundImage
    }
    
    private func updateAppearance() {
        switch style {
        case .video(let duration):
            backgroundImageView.isHidden = false
            gifFileTypeView.isHidden = true
            videoTypeView.isHidden = false
            videoDurationLabel.text = mediaDurationFormatter.string(from: duration)
        case .gif:
            backgroundImageView.isHidden = false
            gifFileTypeView.isHidden = false
            videoTypeView.isHidden = true
        case .hidden:
            backgroundImageView.isHidden = true
            gifFileTypeView.isHidden = true
            videoTypeView.isHidden = true
        }
    }
    
}
