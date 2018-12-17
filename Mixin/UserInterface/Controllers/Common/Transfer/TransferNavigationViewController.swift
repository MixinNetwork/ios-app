import UIKit

class TransferNavigationViewController: UINavigationController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationBar.shadowImage = UIImage()
        navigationBar.backIndicatorImage = UIImage(named: "ic_back_small")
        navigationBar.backIndicatorTransitionMaskImage = UIImage(named: "ic_back_small")
        navigationBar.tintColor = .black
    }
    
}
