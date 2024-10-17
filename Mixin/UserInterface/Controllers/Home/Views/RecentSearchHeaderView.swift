import UIKit

final class RecentSearchHeaderView: UICollectionReusableView {
    
    protocol Delegate: AnyObject {
        func recentSearchHeaderViewDidSendAction(_ view: RecentSearchHeaderView)
    }
    
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var button: UIButton!
    
    weak var delegate: Delegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        label.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        label.text = "Recent Searches"
    }
    
    @IBAction func sendAction(_ sender: Any) {
        delegate?.recentSearchHeaderViewDidSendAction(self)
    }
    
}
