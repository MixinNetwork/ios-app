import UIKit

final class MembershipViewAllOrdersCell: UITableViewCell {
    
    @IBOutlet weak var label: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        label.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        label.text = R.string.localizable.view_all()
    }
    
}
