import UIKit

final class MAONameSearchResultCell: UITableViewCell {
    
    static let height: CGFloat = 98
    
    @IBOutlet weak var peerInfoBackgroundView: UIView!
    @IBOutlet weak var peerInfoView: PeerInfoView!
    @IBOutlet weak var appDisclosureImageView: UIImageView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        peerInfoView.descriptionStackView.spacing = 2
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        let color: UIColor = highlighted ? .selectionBackground : .background
        let work = {
            self.peerInfoBackgroundView.backgroundColor = color
        }
        if animated {
            UIView.animate(withDuration: 0.3, animations: work)
        } else {
            work()
        }
    }
    
    func load(result: MAONameSearchResult) {
        peerInfoView.render(result: result)
        peerInfoView.prefixIconImageView.isHidden = false
        peerInfoView.prefixIconImageView.image = R.image.mao_name()
        appDisclosureImageView.isHidden = result.user.appId == nil
    }
    
}
