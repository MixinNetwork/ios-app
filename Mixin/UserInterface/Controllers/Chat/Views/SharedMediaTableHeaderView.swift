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
        contentView.backgroundColor = .background
        label.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        label.textColor = .accessoryText
        contentView.addSubview(label)
        label.snp.makeConstraints { (make) in
            make.top.bottom.equalToSuperview()
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
        }
    }
    
}
