import UIKit

class TransferNavigationViewController: UINavigationController {
    
    let backImage = UIImage(named: "ic_arrow_left")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationBar.setBackgroundImage(UIImage(), for: .default)
        navigationBar.shadowImage = UIImage()
        navigationBar.backIndicatorImage = backImage
        navigationBar.backIndicatorTransitionMaskImage = backImage
        navigationBar.tintColor = .black
    }
    
}
