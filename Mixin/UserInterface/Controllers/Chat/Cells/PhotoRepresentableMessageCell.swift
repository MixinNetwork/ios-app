import UIKit
import SDWebImage
import YYImage

class PhotoRepresentableMessageCell: DetailInfoMessageCell {
    
    let contentImageView = YYAnimatedImageView()
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
            contentImageView.layer.mask = backgroundImageView.layer
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

}

