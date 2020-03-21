import UIKit

class RecipientHeaderView: UITableViewHeaderFooterView {

    @IBOutlet weak var headerLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()

        backgroundView = UIView(frame: self.bounds)
        backgroundView?.backgroundColor = R.color.background()
    }
}
