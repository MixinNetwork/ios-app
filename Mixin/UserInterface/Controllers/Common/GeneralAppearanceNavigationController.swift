import UIKit

class GeneralAppearanceNavigationController: UINavigationController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = R.color.background()
        navigationBar.standardAppearance = .general
        navigationBar.scrollEdgeAppearance = .general
        navigationBar.tintColor = R.color.icon_tint()
    }
    
}
