import UIKit

final class LoginNavigationController: GeneralAppearanceNavigationController {
    
    init() {
        let onboarding = OnboardingViewController()
        super.init(rootViewController: onboarding)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
}
