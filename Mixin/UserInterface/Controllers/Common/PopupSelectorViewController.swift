import UIKit

class PopupSelectorViewController: UIViewController {
    
    @IBOutlet weak var titleView: PopupTitleView!
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var titleHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var tableViewTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var tableViewBottomConstraint: NSLayoutConstraint!
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    init() {
        let nib = R.nib.popupSelectorView
        super.init(nibName: nib.name, bundle: nib.bundle)
        transitioningDelegate = PopupPresentationManager.shared
        modalPresentationStyle = .custom
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.cornerRadius = 13
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.layer.masksToBounds = true
        titleView.closeButton.addTarget(self, action: #selector(close), for: .touchUpInside)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        updatePreferredContentHeight()
    }
    
    @objc func close(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
    open func updatePreferredContentHeight() {
        preferredContentSize.height = titleHeightConstraint.constant
        + tableViewTopConstraint.constant
        + tableView.contentSize.height
        + tableView.adjustedContentInset.vertical
        + tableViewBottomConstraint.constant
    }
    
}
