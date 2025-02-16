import UIKit
import SnapKit

class GeneralTableViewHeader: UITableViewHeaderFooterView {
    
    var label: UILabel!
    var labelTopConstraint: NSLayoutConstraint!
    var labelBottomConstraint: NSLayoutConstraint!
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        prepare()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    func prepare() {
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
        labelTopConstraint = label.topAnchor.constraint(equalTo: contentView.topAnchor)
        labelTopConstraint.isActive = true
        labelBottomConstraint = label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        labelBottomConstraint.isActive = true
        backgroundConfiguration = {
            var config: UIBackgroundConfiguration = .listPlainHeaderFooter()
            config.backgroundColor = .background
            return config
        }()
    }
    
}
