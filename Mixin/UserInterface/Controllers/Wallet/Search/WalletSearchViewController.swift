import UIKit
import MixinServices

final class WalletSearchViewController<ModelController: WalletSearchModelController>: UIViewController {
    
    @IBOutlet weak var searchBoxWrapperView: UIView!
    @IBOutlet weak var searchBoxView: SearchBoxView!
    @IBOutlet weak var contentWrapperView: UIView!
    
    @IBOutlet weak var keyboardPlaceholderHeightConstraint: NSLayoutConstraint!
    
    var onWillDismiss: (() -> Void)?
    
    private let recommendation: WalletSearchRecommendationViewController<ModelController>
    private let searchResults: WalletSearchResultsViewController<ModelController>
    private let appearingAnimationDistance: CGFloat = 20
    
    private weak var viewCenterYConstraint: NSLayoutConstraint?
    
    init(modelController: ModelController) {
        self.recommendation = WalletSearchRecommendationViewController(modelController: modelController)
        self.searchResults = WalletSearchResultsViewController(modelController: modelController)
        let nib = R.nib.walletSearchView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchBoxView.textField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        searchBoxView.textField.placeholder = R.string.localizable.search_placeholder_asset()
        view.layoutIfNeeded()
        for child in [searchResults, recommendation] {
            addChild(child)
            contentWrapperView.addSubview(child.view)
            child.view.snp.makeConstraints { (make) in
                make.leading.trailing.bottom.equalToSuperview()
                make.top.equalTo(searchBoxWrapperView.snp.bottom).offset(10)
            }
            child.didMove(toParent: self)
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(dismissAsChild),
            name: dismissSearchNotification,
            object: nil
        )
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        searchBoxView.textField.becomeFirstResponder()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        searchBoxView.textField.resignFirstResponder()
    }
    
    @IBAction func cancelAction(_ sender: Any) {
        searchBoxView.textField.resignFirstResponder()
        dismissAsChild()
    }
    
    func presentAsChild(on parent: UIViewController) {
        parent.navigationController?.setNavigationBarHidden(true, animated: true)
        view.alpha = 0
        parent.addChild(self)
        parent.view.addSubview(view)
        view.snp.makeConstraints { (make) in
            make.size.equalTo(parent.view.snp.size)
            make.centerX.equalToSuperview()
        }
        let constraint = view.centerYAnchor.constraint(
            equalTo: parent.view.centerYAnchor,
            constant: -appearingAnimationDistance
        )
        constraint.isActive = true
        didMove(toParent: parent)
        parent.view.layoutIfNeeded()
        UIView.animate(withDuration: 0.5, delay: 0, options: .overdampedCurve) {
            self.view.alpha = 1
            constraint.constant = 0
            parent.view.layoutIfNeeded()
        }
        self.viewCenterYConstraint = constraint
    }
    
    @objc func dismissAsChild() {
        onWillDismiss?()
        let showNavigationBar: Bool
        if let parent = parent as? HomeNavigationController.NavigationBarStyling,
           parent.navigationBarStyle == .hide
        {
            showNavigationBar = false
        } else {
            showNavigationBar = true
        }
        if showNavigationBar {
            parent?.navigationController?.setNavigationBarHidden(false, animated: true)
        }
        UIView.animate(withDuration: 0.5, delay: 0, options: .overdampedCurve) {
            self.view.alpha = 0
            self.viewCenterYConstraint?.constant = -self.appearingAnimationDistance
            self.parent?.view.layoutIfNeeded()
        } completion: { _ in
            self.willMove(toParent: nil)
            self.view.removeFromSuperview()
            self.removeFromParent()
        }
    }
    
    @objc private func textFieldDidChange(_ textField: UITextField) {
        guard textField.markedTextRange == nil else {
            return
        }
        let keyword = (textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        searchResults.update(with: keyword)
        if keyword.isEmpty {
            if contentWrapperView.subviews.last == searchResults.view {
                recommendation.tableView.setContentOffset(.zero, animated: false)
            }
            contentWrapperView.bringSubviewToFront(recommendation.view)
        } else {
            contentWrapperView.bringSubviewToFront(searchResults.view)
        }
    }
    
    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        guard let userInfo = notification.userInfo else {
            return
        }
        guard let endFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        keyboardPlaceholderHeightConstraint.constant = view.bounds.height - endFrame.origin.y
        view.layoutIfNeeded()
    }
    
}
