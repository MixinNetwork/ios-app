import UIKit
import SDWebImage
import YYImage

class PhotoRepresentableMessageCell: DetailInfoMessageCell {
    
    let maskingContentView = UIView()
    let contentImageView = VerticalPositioningImageView()
    let shadowImageView = UIImageView(image: PhotoRepresentableMessageViewModel.shadowImage)
    
    lazy var selectedOverlapView: UIView = {
        let view = SelectedOverlapView()
        view.alpha = 0
        contentView.addSubview(view)
        return view
    }()
    
    internal lazy var statusViews = [
        shadowImageView,
        timeLabel,
        statusImageView
    ]
    
    override var contentFrame: CGRect {
        return contentImageView.frame
    }

    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? PhotoRepresentableMessageViewModel {
            contentImageView.position = viewModel.layoutPosition
            contentImageView.frame = viewModel.contentFrame
            selectedOverlapView.frame = contentImageView.bounds
            shadowImageView.frame = CGRect(origin: viewModel.shadowImageOrigin,
                                           size: shadowImageView.image?.size ?? .zero)
        }
    }
    
    override func prepare() {
        contentView.addSubview(maskingContentView)
        maskingContentView.frame = contentView.bounds
        maskingContentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        maskingContentView.addSubview(contentImageView)
        shadowImageView.contentMode = .scaleToFill
        shadowImageView.clipsToBounds = true
        maskingContentView.addSubview(shadowImageView)
        timeLabel.textColor = .white
        updateAppearance(highlight: false, animated: false)
        contentImageView.addSubview(selectedOverlapView)
        super.prepare()
        backgroundImageView.removeFromSuperview()
        maskingContentView.layer.masksToBounds = true
        maskingContentView.layer.mask = backgroundImageView.layer
    }
    
    override func updateAppearance(highlight: Bool, animated: Bool) {
        UIView.animate(withDuration: animated ? highlightAnimationDuration : 0) {
            self.selectedOverlapView.alpha = highlight ? 1 : 0
        }
    }
    
    func reloadMedia(viewModel: PhotoRepresentableMessageViewModel) {
        
    }
    
}

extension PhotoRepresentableMessageCell {

    class SelectedOverlapView: UIView {

        override var backgroundColor: UIColor? {
            set {

            }
            get {
                return super.backgroundColor
            }
        }
        
        private let dimmingColor = UIColor.black.withAlphaComponent(0.2)
        
        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
            super.backgroundColor = dimmingColor
        }
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            super.backgroundColor = dimmingColor
        }

    }
    
}

