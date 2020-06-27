import UIKit

class GroupCallMemberCell: UICollectionViewCell {
    
    @IBOutlet weak var avatarImageView: AvatarImageView!
    @IBOutlet weak var connectingView: UIView!
    
    private let dotLength: CGFloat = 6
    private let dotSpacing: CGFloat = 4
    
    private var dotLayers = [CALayer]()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        for _ in 0...2 {
            let dotLayer = CALayer()
            dotLayer.frame.size = CGSize(width: dotLength, height: dotLength)
            dotLayer.cornerRadius = dotLength / 2
            dotLayer.backgroundColor = UIColor.white.withAlphaComponent(0.6).cgColor
            connectingView.layer.addSublayer(dotLayer)
            dotLayers.append(dotLayer)
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        avatarImageView.layer.cornerRadius = avatarImageView.bounds.width / 2
        connectingView.layer.cornerRadius = connectingView.bounds.width / 2
        dotLayers[0].position = CGPoint(x: bounds.midX - dotSpacing - dotLength,
                                        y: bounds.midY)
        dotLayers[1].position = CGPoint(x: bounds.midX,
                                        y: bounds.midY)
        dotLayers[2].position = CGPoint(x: bounds.midX + dotSpacing + dotLength,
                                        y: bounds.midY)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        avatarImageView.prepareForReuse()
    }
    
}
