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
        
        let backIndicatorImage = R.image.navigation_back()
        let backgroundColor = R.color.background()
        if #available(iOS 15.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = backgroundColor
            appearance.shadowColor = nil
            appearance.setBackIndicatorImage(backIndicatorImage, transitionMaskImage: backIndicatorImage)
            appearance.backButtonAppearance = {
                let appearance = UIBarButtonItemAppearance()
                appearance.normal.titleTextAttributes = [.foregroundColor: UIColor.clear]
                return appearance
            }()
            navigationBar.standardAppearance = appearance
            navigationBar.scrollEdgeAppearance = appearance
        } else {
            navigationBar.backgroundColor = backgroundColor
            navigationBar.backIndicatorImage = backIndicatorImage
            navigationBar.backIndicatorTransitionMaskImage = backIndicatorImage
        }
        navigationBar.tintColor = R.color.icon_tint()
    }
    
}
