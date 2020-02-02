import UIKit
import MixinServices

final class UserAvatarStackView: UIView {
    
    var avatarBackgroundColor = UIColor.background
    
    var iconLength: CGFloat = 34 {
        didSet {
            setNeedsLayout()
        }
    }
    
    var users = [User]() {
        didSet {
            reloadData()
        }
    }
    
    private let maxNumberOfAvatars = 3
    
    private var imageViews = [BorderedAvatarImageView]()
    
    override var intrinsicContentSize: CGSize {
        let width = (CGFloat(imageViews.count - 1) / 2 + 1) * iconLength
        return CGSize(width: width, height: iconLength)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        for (index, imageView) in imageViews.enumerated() {
            imageView.bounds.size = CGSize(width: iconLength, height: iconLength)
            if index == 0 {
                imageView.center = CGPoint(x: iconLength / 2, y: bounds.midY)
            } else {
                let previousCenter = imageViews[index - 1].center
                imageView.center = CGPoint(x: previousCenter.x + iconLength / 2, y: bounds.midY)
            }
        }
    }
    
    private func reloadData() {
        for imageView in imageViews {
            imageView.prepareForReuse()
        }
        let topUsers = users.prefix(maxNumberOfAvatars)
        if imageViews.count < topUsers.count {
            for _ in 0..<(topUsers.count - imageViews.count) {
                let imageView = BorderedAvatarImageView()
                imageView.backgroundView.backgroundColor = avatarBackgroundColor
                addSubview(imageView)
                imageViews.insert(imageView, at: 0)
            }
            invalidateIntrinsicContentSize()
        } else if imageViews.count > topUsers.count {
            imageViews.removeLast(imageViews.count - topUsers.count)
            invalidateIntrinsicContentSize()
        }
        for (index, imageView) in imageViews.enumerated() {
            imageView.setImage(with: topUsers[index])
        }
    }
    
}
