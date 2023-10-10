import UIKit

final class AssetMigrationViewController: UIViewController {
    
    @IBOutlet weak var titleView: PopupTitleView!
    
    init() {
        let nib = R.nib.assetMigrationView
        super.init(nibName: nib.name, bundle: nib.bundle)
        self.title = title
        self.modalPresentationStyle = .custom
        self.transitioningDelegate = PopupPresentationManager.shared
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.layer.cornerRadius = 13
        titleView.closeButton.addTarget(self, action: #selector(close(_:)), for: .touchUpInside)
        preferredContentSize.height = 465
    }
    
    @objc private func close(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
    @IBAction func startMigration(_ sender: Any) {
        
    }
    
}
