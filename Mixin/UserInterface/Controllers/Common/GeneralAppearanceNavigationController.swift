import UIKit

class GeneralAppearanceNavigationController: UINavigationController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = R.color.background()
        navigationBar.standardAppearance = .general
        navigationBar.scrollEdgeAppearance = .transparent
        navigationBar.compactAppearance = .general
        navigationBar.compactScrollEdgeAppearance = .transparent
        navigationBar.tintColor = R.color.icon_tint()
    }
    
}
