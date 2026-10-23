import UIKit
import MixinServices

final class WalletSearchViewController<ModelController: WalletSearchModelController>: UIViewController, SearchNavigationAnimating {
    
    @IBOutlet weak var contentWrapperView: UIView!
    
    @IBOutlet weak var keyboardPlaceholderHeightConstraint: NSLayoutConstraint!
    
    private let searchBoxView = SearchBoxView()
    private let recommendation: WalletSearchRecommendationViewController<ModelController>
    private let searchResults: WalletSearchResultsViewController<ModelController>
    
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
        navigationItem.hidesBackButton = true
        navigationItem.titleView = searchBoxView
        navigationItem.rightBarButtonItem = .cancelSearch(
            target: self,
            action: #selector(cancelAction(_:))
        )
        
        view.layoutIfNeeded()
        for child in [searchResults, recommendation] {
            addChild(child)
            contentWrapperView.addSubview(child.view)
            child.view.snp.makeConstraints { (make) in
                make.leading.trailing.bottom.equalToSuperview()
                make.top.equalToSuperview().offset(10)
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
            selector: #selector(dismissSearch),
            name: dismissSearchNotification,
            object: nil
        )
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if isMovingToParent {
            searchBoxView.textField.becomeFirstResponder()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        searchBoxView.textField.resignFirstResponder()
    }
    
    @IBAction func cancelAction(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func dismissSearch() {
        guard let navigationController else {
            return
        }
        let viewControllers = navigationController.viewControllers.filter { $0 !== self }
        navigationController.setViewControllers(viewControllers, animated: false)
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
        let keyboardFrame = view.convert(endFrame, from: nil)
        keyboardPlaceholderHeightConstraint.constant = max(0, view.bounds.maxY - keyboardFrame.minY)
        view.layoutIfNeeded()
    }
    
}
