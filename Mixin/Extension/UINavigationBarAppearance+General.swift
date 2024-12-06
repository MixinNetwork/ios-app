import UIKit

extension UINavigationBarAppearance {
    
    static let general: UINavigationBarAppearance = {
        let backIndicatorImage = R.image.navigation_back()
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = R.color.background()
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
    
    static let secondaryBackgroundColor: UINavigationBarAppearance = {
        let backIndicatorImage = R.image.navigation_back()
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = R.color.background_secondary()
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
    
}
