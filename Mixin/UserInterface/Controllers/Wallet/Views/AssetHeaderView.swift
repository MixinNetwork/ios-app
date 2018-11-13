import UIKit
import SnapKit

class AssetHeaderView: UITableViewHeaderFooterView {
    
    let leftShadowImageView = UIImageView()
    let rightShadowImageView = UIImageView()
    let labelBackgroundView = UIView()
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
        backgroundColor = .white
        contentView.backgroundColor = .white
        clipsToBounds = true
        leftShadowImageView.image = UIImage(named: "Wallet/bg_shadow_left")
        contentView.addSubview(leftShadowImageView)
        leftShadowImageView.snp.makeConstraints { (make) in
            make.top.bottom.equalToSuperview()
            make.trailing.equalTo(contentView.snp.leading).offset(10)
        }
        rightShadowImageView.image = UIImage(named: "Wallet/bg_shadow_right")
        contentView.addSubview(rightShadowImageView)
        rightShadowImageView.snp.makeConstraints { (make) in
            make.top.bottom.equalToSuperview()
            make.leading.equalTo(contentView.snp.trailing).offset(-10)
        }
        labelBackgroundView.backgroundColor = UIColor(rgbValue: 0xFCFCFC)
        contentView.addSubview(labelBackgroundView)
        labelBackgroundView.snp.makeConstraints { (make) in
            make.leading.equalTo(leftShadowImageView.snp.trailing)
            make.trailing.equalTo(rightShadowImageView.snp.leading)
            make.top.bottom.equalToSuperview()
        }
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = UIColor(rgbValue: 0xBBBEC3)
        label.translatesAutoresizingMaskIntoConstraints = false
        labelBackgroundView.addSubview(label)
        label.snp.makeConstraints { (make) in
            make.centerY.equalToSuperview().offset(3)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
        }
    }
    
}
