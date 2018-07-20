import UIKit

class TransactionCell: UITableViewCell {

    static let cellIdentifier = "TransactionCell"

    @IBOutlet weak var itemLabel: UILabel!
    @IBOutlet weak var descLabel: UILabel!

    func render(title: String, value: String?) {
        itemLabel.text = title
        descLabel.text = value
    }

}
