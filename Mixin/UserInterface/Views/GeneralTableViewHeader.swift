import UIKit

class GeneralTableViewHeader: UITableViewHeaderFooterView {

    var label: UILabel!
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        prepare()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    private func prepare() {
        clipsToBounds = true
        label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = .darkText
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        let constraints = [label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
                           label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)]
        NSLayoutConstraint.activate(constraints)

        contentView.backgroundColor = .white
    }
    
}
