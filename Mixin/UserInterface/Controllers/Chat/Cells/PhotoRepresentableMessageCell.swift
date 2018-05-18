import UIKit
import SDWebImage
import FLAnimatedImage

class PhotoRepresentableMessageCell: DetailInfoMessageCell {
    
    let contentImageView = FLAnimatedImageView()
    let shadowImageView = UIImageView()
    
    override var contentFrame: CGRect {
        return contentImageView.frame
    }

    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? PhotoRepresentableMessageViewModel {
            contentImageView.frame = viewModel.contentFrame
            contentImageView.layer.mask = backgroundImageView.layer
           
            shadowImageView.image = viewModel.shadowImage
            shadowImageView.frame = CGRect(origin: viewModel.shadowImageOrigin,
                                           size: viewModel.shadowImage?.size ?? .zero)
        }
    }
    
    override func prepare() {
        contentView.addSubview(contentImageView)
        contentImageView.contentMode = .scaleAspectFill
        contentImageView.clipsToBounds = true
        contentImageView.layer.cornerRadius = 6
        timeLabel.textColor = .white
        shadowImageView.contentMode = .scaleToFill
        shadowImageView.layer.cornerRadius = 6
        shadowImageView.clipsToBounds = true
        contentView.addSubview(shadowImageView)
        super.prepare()
        backgroundImageView.removeFromSuperview()
    }

    func contentSnapshotView(afterScreenUpdates: Bool) -> UIView {
        let view = UIImageView(frame: contentFrame)
        view.contentMode = .scaleAspectFit
        UIGraphicsBeginImageContextWithOptions(contentFrame.size, false, UIScreen.main.scale)
        contentImageView.drawHierarchy(in: view.bounds, afterScreenUpdates: afterScreenUpdates)
        let shadowRect = shadowImageView.convert(shadowImageView.bounds, to: contentImageView)
        shadowImageView.drawHierarchy(in: shadowRect, afterScreenUpdates: afterScreenUpdates)
        let timeRect = timeLabel.convert(timeLabel.bounds, to: contentImageView)
        timeLabel.drawHierarchy(in: timeRect, afterScreenUpdates: afterScreenUpdates)
        let statusRect = statusImageView.convert(statusImageView.bounds, to: contentImageView)
        statusImageView.drawHierarchy(in: statusRect, afterScreenUpdates: afterScreenUpdates)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        view.image = image
        return view
    }
    
}

