import UIKit
import SnapKit

class GeneralTableViewHeader: UITableViewHeaderFooterView {
    
    var label: UILabel!
    var labelTopConstraint: NSLayoutConstraint!
    
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
        label.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        label.textColor = .text
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        label.snp.makeConstraints { (make) in
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20).priority(.almostRequired)
        }
        labelTopConstraint = label.topAnchor.constraint(equalTo: topAnchor)
        labelTopConstraint.isActive = true
        contentView.backgroundColor = .background
    }
    
}
