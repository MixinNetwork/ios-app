import UIKit

final class UserHandleTableHeaderView: UIView {
    
    private let shadowView = TopShadowView()
    private let decorationView = UIView()
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        prepare()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    private func prepare() {
        shadowView.isUserInteractionEnabled = false
        shadowView.backgroundColor = .clear
        addSubview(shadowView)
        decorationView.isUserInteractionEnabled = false
        decorationView.backgroundColor = .background
        addSubview(decorationView)
        decorationView.snp.makeConstraints { (make) in
            make.leading.trailing.bottom.equalToSuperview()
            make.height.equalTo(7)
        }
        shadowView.snp.makeConstraints { (make) in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(decorationView.snp.top)
            make.height.equalTo(10)
        }
    }
    
}
