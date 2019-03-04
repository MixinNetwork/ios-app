import UIKit

class AssetFilterHeaderView: UICollectionReusableView {
    
    let label = UILabel()
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    private func prepare() {
        label.font = .systemFont(ofSize: 14)
        label.textColor = UIColor(rgbValue: 0x333333)
        addSubview(label)
        label.snp.makeConstraints { (make) in
            make.top.leading.trailing.equalToSuperview()
        }
    }
    
}
