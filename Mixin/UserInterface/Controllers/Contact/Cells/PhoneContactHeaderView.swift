import UIKit

class PhoneContactHeaderView: UITableViewHeaderFooterView {
    
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
        backgroundView = UIView()
        backgroundView?.backgroundColor = .white
        label.font = .systemFont(ofSize: 14)
        label.textColor = .darkText
        contentView.addSubview(label)
        label.snp.makeConstraints { (make) in
            make.top.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20).priority(999)
        }
    }
    
}

