import UIKit

class FilterableHeaderView: UITableViewHeaderFooterView {
    
    let titleLabel = UILabel()
    let filterButton = UIButton(type: .custom)
    
    var filterAction: (() -> Void)?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        prepare()
    }
    
    @objc func filterAction(_ sender: Any) {
        filterAction?()
    }
    
    private func prepare() {
        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.textColor = .headerGray
        titleLabel.text = Localized.TRANSFER_TRANSACTIONS
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { (make) in
            make.left.equalToSuperview().offset(18)
            make.top.bottom.equalToSuperview()
        }
        filterButton.setImage(UIImage(named: "ic_filter"), for: .normal)
        filterButton.addTarget(self, action: #selector(filterAction(_:)), for: .touchUpInside)
        contentView.addSubview(filterButton)
        filterButton.snp.makeConstraints { (make) in
            make.width.equalTo(filterButton.snp.height)
            make.left.equalTo(self.titleLabel.snp.right).priority(.almostRequired)
            make.top.bottom.rightMargin.equalToSuperview()
        }
    }
    
}
