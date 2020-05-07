import UIKit

class LoneBackButtonNavigationController: UINavigationController {

    let backButton = UIButton()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setNavigationBarHidden(true, animated: false)
        UIApplication.shared.keyWindow?.endEditing(true)
        backButton.tintColor = R.color.icon_tint()
        backButton.setImage(R.image.ic_title_back(), for: .normal)
        backButton.addTarget(self, action: #selector(backAction(sender:)), for: .touchUpInside)
        backButton.alpha = 0
        backButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backButton)
        backButton.snp.makeConstraints { (make) in
            make.width.height.equalTo(44)
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.topMargin)
            make.leading.equalTo(self.view.safeAreaLayoutGuide.snp.leadingMargin).offset(10)
        }
    }
    
    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        defer {
            updateBackButtonAlpha(animated: animated)
        }
        return super.pushViewController(viewController, animated: animated)
    }
    
    @discardableResult
    override func popViewController(animated: Bool) -> UIViewController? {
        defer {
            updateBackButtonAlpha(animated: animated)
        }
        return super.popViewController(animated: animated)
    }
    
    @discardableResult
    override func popToViewController(_ viewController: UIViewController, animated: Bool) -> [UIViewController]?  {
        defer {
            updateBackButtonAlpha(animated: animated)
        }
        return super.popToViewController(viewController, animated: animated)
    }
    
    @discardableResult
    override func popToRootViewController(animated: Bool) -> [UIViewController]?  {
        defer {
            updateBackButtonAlpha(animated: animated)
        }
        return super.popToRootViewController(animated: animated)
    }
    
    @objc func backAction(sender: Any) {
        popViewController(animated: true)
    }
    
    func updateBackButtonAlpha(animated: Bool) {
        
    }
    
}
