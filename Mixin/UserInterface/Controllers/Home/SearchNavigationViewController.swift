import UIKit

class SearchNavigationViewController: UINavigationController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let image = UIColor.white.image
        navigationBar.setBackgroundImage(image, for: .default)
        navigationBar.shadowImage = image
    }
    
}
