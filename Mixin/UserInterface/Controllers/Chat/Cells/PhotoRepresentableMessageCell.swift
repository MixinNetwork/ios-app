import UIKit
import SDWebImage
import YYImage

class PhotoRepresentableMessageCell: DetailInfoMessageCell {
    
    let contentImageView = VerticalPositioningImageView()
    let shadowImageView = UIImageView()
    
    lazy var selectedOverlapView: UIView = {
        let view = SelectedOverlapView()
        view.alpha = 0
        contentView.addSubview(view)
        return view
    }()
    
    internal lazy var contentSnapshotViews = [
        contentImageView,
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
            contentImageView.frame = viewModel.contentFrame
            selectedOverlapView.frame = contentImageView.bounds

            shadowImageView.image = viewModel.shadowImage
            shadowImageView.frame = CGRect(origin: viewModel.shadowImageOrigin,
                                           size: viewModel.shadowImage?.size ?? .zero)
        }
    }
    
    override func prepare() {
        contentImageView.contentMode = .scaleAspectFill
        contentImageView.clipsToBounds = true
        contentImageView.layer.cornerRadius = 6
        contentView.addSubview(contentImageView)
        shadowImageView.contentMode = .scaleToFill
        shadowImageView.layer.cornerRadius = 6
        shadowImageView.clipsToBounds = true
        contentView.addSubview(shadowImageView)
        timeLabel.textColor = .white
        updateAppearance(highlight: false, animated: false)
        contentImageView.addSubview(selectedOverlapView)
        super.prepare()
        backgroundImageView.removeFromSuperview()
        contentImageView.layer.mask = backgroundImageView.layer
    }
    
    override func updateAppearance(highlight: Bool, animated: Bool) {
        UIView.animate(withDuration: animated ? highlightAnimationDuration : 0) {
            self.selectedOverlapView.alpha = highlight ? 1 : 0
        }
    }

    func contentSnapshotView(afterScreenUpdates: Bool) -> UIView {
        let view = UIImageView(frame: contentFrame)
        view.contentMode = .scaleAspectFit
        UIGraphicsBeginImageContextWithOptions(contentFrame.size, false, UIScreen.main.scale)
        for view in contentSnapshotViews {
            let rect = view.convert(view.bounds, to: contentImageView)
            view.drawHierarchy(in: rect, afterScreenUpdates: afterScreenUpdates)
        }
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        view.image = image
        return view
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
    
    class VerticalPositioningImageView: UIView {
        
        enum Position {
            case top, center
        }
        
        let imageView = YYAnimatedImageView()

        var position = Position.center {
            didSet {
                setNeedsLayout()
            }
        }
        
        var image: UIImage? {
            get {
                return imageView.image
            }
            set {
                aspectRatio = newValue?.size ?? .zero
                imageView.image = newValue
                setNeedsLayout()
            }
        }
        
        var aspectRatio = CGSize.zero
        
        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
            prepare()
        }
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            prepare()
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            if aspectRatio.width <= 1 {
                aspectRatio = CGSize(width: 1, height: 1)
            }
            imageView.bounds.size = CGSize(width: bounds.width, height: bounds.width * aspectRatio.height / aspectRatio.width)
            switch position {
            case .center:
                imageView.center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
            case .top:
                imageView.frame.origin = .zero
            }
        }
        
        func setImage(with url: URL, ratio: CGSize) {
            imageView.sd_setImage(with: url, completed: nil)
            aspectRatio = ratio
            setNeedsLayout()
        }
        
        func cancelCurrentImageLoad() {
            imageView.sd_cancelCurrentImageLoad()
        }
        
        private func prepare() {
            addSubview(imageView)
            imageView.contentMode = .scaleToFill
            clipsToBounds = true
        }
        
    }

}

