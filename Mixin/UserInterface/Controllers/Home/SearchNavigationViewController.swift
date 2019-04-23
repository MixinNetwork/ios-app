import UIKit

class SearchNavigationViewController: UINavigationController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let image = UIColor.white.image
        navigationBar.setBackgroundImage(image, for: .default)
        navigationBar.shadowImage = image
        navigationBar.backIndicatorImage = R.image.ic_search_back()
        navigationBar.backIndicatorTransitionMaskImage = R.image.ic_search_back()
    }
    
}
