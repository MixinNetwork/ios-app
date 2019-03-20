import UIKit

class PhoneContactHeaderFooter: UITableViewHeaderFooterView {

    @IBOutlet weak var sectionTitleLabel: UILabel!

    static let cellIdentifier = "cell_identifier_phone_contact_header_footer"

    override func awakeFromNib() {
        super.awakeFromNib()

        contentView.backgroundColor = UIColor.white
        backgroundView = UIView()
        backgroundView?.backgroundColor = UIColor.white
    }
}

