import UIKit

func showHud(style: Hud.Style, text: String) {
    if Thread.isMainThread {
        guard let window = AppDelegate.current.window else {
            return
        }
        Hud.show(style: style, text: text, on: window)
    } else {
        DispatchQueue.main.async {
            guard let window = AppDelegate.current.window else {
                return
            }
            Hud.show(style: style, text: text, on: window)
        }
    }
}

class Hud {
    
    enum Style {
        case notification
        case warning
        case error
    }
    
    class View: UIVisualEffectView {
        
        let imageView = UIImageView()
        let label = UILabel()
        
        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
            prepare()
        }
        
        override init(effect: UIVisualEffect?) {
            super.init(effect: effect)
            prepare()
        }
        
        func render(style: Style, text: String) {
            switch style {
            case .notification:
                imageView.image = UIImage(named: "ic_hud_notification")
            case .warning:
                imageView.image = UIImage(named: "ic_hud_warning")
            case .error:
                imageView.image = UIImage(named: "ic_hud_error")
            }
            label.text = text
        }
        
        private func prepare() {
            label.font = .systemFont(ofSize: 15)
            label.textColor = .white
            label.textAlignment = .center
            label.numberOfLines = 0
            contentView.addSubview(imageView)
            contentView.addSubview(label)
            imageView.snp.makeConstraints { (make) in
                make.width.height.equalTo(30)
                make.top.equalToSuperview().offset(30)
                make.centerX.equalToSuperview()
            }
            label.snp.makeConstraints { (make) in
                make.top.equalTo(imageView.snp.bottom).offset(12)
                make.leading.equalToSuperview().offset(16)
                make.trailing.equalToSuperview().offset(-16)
                make.bottom.equalToSuperview().offset(-20)
            }
            layer.cornerRadius = 8
            clipsToBounds = true
        }
        
    }
    
    static func show(style: Style, text: String, on view: UIView) {
        let container = UIView(frame: view.bounds)
        container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(container)
        let hudView = View(effect: UIBlurEffect(style: .dark))
        hudView.render(style: style, text: text)
        hudView.alpha = 0
        container.addSubview(hudView)
        hudView.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
            make.width.lessThanOrEqualTo(view.snp.width).multipliedBy(0.5)
            make.height.lessThanOrEqualTo(view.snp.height).multipliedBy(0.5)
            make.width.greaterThanOrEqualTo(130)
            make.height.greaterThanOrEqualTo(100)
        }
        UIView.animate(withDuration: 0.2) {
            hudView.alpha = 1
        }
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: .beginFromCurrentState, animations: {
            hudView.alpha = 1
        }, completion: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            UIView.animate(withDuration: 0.2, animations: {
                hudView.alpha = 0
            }, completion: { (_) in
                container.removeFromSuperview()
            })
        }
    }
    
}
