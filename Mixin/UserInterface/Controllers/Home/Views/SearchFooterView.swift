import UIKit

class SearchFooterView: UITableViewHeaderFooterView {
    
    static let height: CGFloat = 30
    
    let topView = UIView()
    let shadowView = BottomShadowView()
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        prepare()
    }
    
    private func prepare() {
        topView.backgroundColor = .background
        contentView.addSubview(shadowView)
        contentView.addSubview(topView)
        topView.snp.makeConstraints { (make) in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(20)
        }
        shadowView.snp.makeConstraints { (make) in
            make.leading.bottom.trailing.equalToSuperview()
            make.height.equalTo(10)
        }
    }
    
}
