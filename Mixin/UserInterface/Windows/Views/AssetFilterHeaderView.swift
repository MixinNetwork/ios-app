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
        label.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        label.textColor = .text
        addSubview(label)
        label.snp.makeConstraints { (make) in
            make.top.leading.trailing.equalToSuperview()
        }
    }
    
}
