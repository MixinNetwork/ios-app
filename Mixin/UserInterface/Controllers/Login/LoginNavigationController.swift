import UIKit

final class LoginNavigationController: GeneralAppearanceNavigationController {
    
    init() {
        let onboarding = OnboardingViewController()
        super.init(rootViewController: onboarding)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let presentLogRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(presentLog(_:)))
        navigationBar.addGestureRecognizer(presentLogRecognizer)
    }
    
    @objc private func presentLog(_ sender: UILongPressGestureRecognizer) {
        switch sender.state {
        case .began:
            var topMost: UIViewController = self
            while let next = topMost.presentedViewController, !next.isBeingDismissed {
                topMost = next
            }
            let log = LoginLogViewController()
            topMost.present(log, animated: true)
        default:
            break
        }
    }
    
}
