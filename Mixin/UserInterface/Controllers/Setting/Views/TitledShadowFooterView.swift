import UIKit

class TitledShadowFooterView: UITableViewHeaderFooterView {
    
    let shadowView = SeparatorShadowView()
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
        backgroundView?.backgroundColor = .white
        label.font = .systemFont(ofSize: 12)
        label.textColor = .accessoryText
        label.numberOfLines = 0
        contentView.addSubview(shadowView)
        contentView.addSubview(label)
        shadowView.snp.makeConstraints { (make) in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(10)
        }
        label.snp.makeConstraints { (make) in
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.top.equalTo(shadowView.snp.bottom).offset(2)
            make.bottom.equalToSuperview().offset(-16)
        }
    }
    
}
