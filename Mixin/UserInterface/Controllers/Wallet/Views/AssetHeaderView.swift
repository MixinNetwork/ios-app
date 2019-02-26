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
        contentView.backgroundColor = .white
        clipsToBounds = true
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = UIColor(rgbValue: 0xBBBEC3)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        label.snp.makeConstraints { (make) in
            make.top.equalToSuperview().offset(10)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
        }
    }
    
}
