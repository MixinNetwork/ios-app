import UIKit

class SharedMediaTableHeaderView: UITableViewHeaderFooterView {
    
    let label = UILabel()
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        prepare()
    }
    
    private func prepare() {
        contentView.backgroundColor = .white
        label.font = .systemFont(ofSize: 14)
        label.textColor = UIColor(displayP3RgbValue: 0xB8BDC7)
        contentView.addSubview(label)
        label.snp.makeConstraints { (make) in
            make.top.bottom.equalToSuperview()
            make.leading.equalToSuperview().offset(10)
            make.trailing.equalToSuperview().offset(-10)
        }
    }
    
}
