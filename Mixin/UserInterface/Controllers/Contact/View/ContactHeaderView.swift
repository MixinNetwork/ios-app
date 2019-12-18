import UIKit

class ContactHeaderView: UITableViewHeaderFooterView {
    
    @IBOutlet weak var label: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()

        backgroundView = UIView(frame: self.bounds)
        backgroundView?.backgroundColor = .background
    }

}
