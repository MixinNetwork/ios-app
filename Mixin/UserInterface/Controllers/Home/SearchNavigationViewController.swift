import UIKit

final class SearchNavigationViewController: UINavigationController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let backIndicatorImage = if #available(iOS 26, *) {
            R.image.navigation_back()
        } else {
            R.image.ic_search_back()
        }
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = R.color.background()
        appearance.shadowColor = nil
        appearance.setBackIndicatorImage(backIndicatorImage, transitionMaskImage: backIndicatorImage)
        appearance.titleTextAttributes = [.foregroundColor: UIColor.clear]
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
    }
    
}
