import UIKit

class LoginLoadingViewController: UIViewController {
    
    @IBOutlet weak var bottomStackView: UIStackView!
    @IBOutlet weak var activityIndicator: ActivityIndicatorView!
    @IBOutlet weak var descriptionLabel: UILabel!
    
    init() {
        let nib = R.nib.loginLoadingView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
}
