import UIKit

extension UINavigationBarAppearance {
    
    static let general: UINavigationBarAppearance = {
        let backIndicatorImage = R.image.navigation_back()
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.shadowColor = nil
        appearance.setBackIndicatorImage(backIndicatorImage, transitionMaskImage: backIndicatorImage)
        appearance.backButtonAppearance = {
            let appearance = UIBarButtonItemAppearance()
            appearance.normal.titleTextAttributes = [.foregroundColor: UIColor.clear]
            return appearance
        }()
        appearance.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: R.color.text()!,
        ]
        return appearance
    }()
    
    static let transparent: UINavigationBarAppearance = {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.shadowColor = nil
        appearance.setBackIndicatorImage(
            general.backIndicatorImage,
            transitionMaskImage: general.backIndicatorTransitionMaskImage,
        )
        appearance.backButtonAppearance = general.backButtonAppearance
        appearance.titleTextAttributes = general.titleTextAttributes
        return appearance
    }()
    
}
