import UIKit

final class BadgeBarButtonView: UIView {
    
    let badgeView = UIView()
    let button = UIButton(type: .system)
    
    override var intrinsicContentSize: CGSize {
        CGSize(width: 46, height: 44)
    }
    
    init(image: UIImage, target: Any, action: Selector) {
        let frame = CGRect(x: 0, y: 0, width: 46, height: 44)
        super.init(frame: frame)
        clipsToBounds = false
        addSubviews()
        button.setImage(image, for: .normal)
        button.addTarget(target, action: action, for: .touchUpInside)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        addSubviews()
    }
    
    private func addSubviews() {
        addSubview(button)
        button.snp.makeEdgesEqualToSuperview()
        
        badgeView.isHidden = true
        badgeView.backgroundColor = R.color.error_red()
        badgeView.layer.cornerRadius = 4
        badgeView.layer.masksToBounds = true
        addSubview(badgeView)
        badgeView.snp.makeConstraints { make in
            make.width.height.equalTo(8)
            make.centerX.equalToSuperview().offset(14)
            make.centerY.equalToSuperview().offset(-8)
        }
    }
    
}
