import UIKit

final class SecondaryAppearanceNavigationController: UINavigationController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = R.color.background_secondary()
        navigationBar.standardAppearance = .secondaryBackgroundColor
        navigationBar.scrollEdgeAppearance = .secondaryBackgroundColor
        navigationBar.tintColor = R.color.icon_tint()
    }
    
}
