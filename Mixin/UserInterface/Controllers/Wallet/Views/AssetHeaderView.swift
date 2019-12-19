import UIKit
import SnapKit

class AssetHeaderView: UITableViewHeaderFooterView {
    
    let label = UILabel()
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        prepare()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    private func prepare() {
        contentView.backgroundColor = .background
        clipsToBounds = true
        label.font = .preferredFont(forTextStyle: .caption1)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .accessoryText
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        label.snp.makeConstraints { (make) in
            make.top.equalToSuperview().offset(20)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
        }
    }
    
}
