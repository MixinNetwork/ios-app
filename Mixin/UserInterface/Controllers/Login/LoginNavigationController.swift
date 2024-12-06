import UIKit

final class LoginNavigationController: UINavigationController {
    
    init() {
        let onboarding = OnboardingViewController()
        super.init(rootViewController: onboarding)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationBar.standardAppearance = .general
        navigationBar.scrollEdgeAppearance = .general
        navigationBar.tintColor = R.color.icon_tint()
    }
    
}
