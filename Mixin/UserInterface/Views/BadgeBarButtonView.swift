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
        
        button.setImage(image, for: .normal)
        button.addTarget(target, action: action, for: .touchUpInside)
        addSubview(button)
        button.snp.makeEdgesEqualToSuperview()
        
        badgeView.isHidden = true
        badgeView.backgroundColor = R.color.error_red()
        badgeView.layer.cornerRadius = 4
        badgeView.layer.masksToBounds = true
        addSubview(badgeView)
        badgeView.snp.makeConstraints { make in
            make.width.height.equalTo(8)
            if let imageView = button.imageView {
                make.top.equalTo(imageView.snp.top)
                make.leading.equalTo(imageView.snp.trailing).offset(-2)
            } else {
                make.top.equalToSuperview()
                make.leading.equalToSuperview().offset(-6)
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
}
