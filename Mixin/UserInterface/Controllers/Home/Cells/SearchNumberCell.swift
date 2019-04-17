import UIKit

class SearchNumberCell: UITableViewCell {
    
    @IBOutlet weak var label: UILabel!
    
    private let numberAttributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 14)
    ]
    
    private let prefix: NSAttributedString = {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14)
        ]
        let plain = R.string.localizable.search_placeholder_number()
        let str = NSAttributedString(string: plain, attributes: attrs)
        return str
    }()
    
    func render(number: String) {
        let text = NSAttributedString(string: number, attributes: numberAttributes)
        label.attributedText = text
    }
    
}
