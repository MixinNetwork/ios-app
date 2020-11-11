import UIKit

class WalletSearchViewController: UIViewController {
    
    @IBOutlet weak var searchBoxWrapperView: UIView!
    @IBOutlet weak var searchBoxView: SearchBoxView!
    @IBOutlet weak var contentWrapperView: UIView!
    
    @IBOutlet weak var keyboardPlaceholderHeightConstraint: NSLayoutConstraint!
    
    private let recommendation = WalletSearchRecommendationViewController()
    private let searchResults = WalletSearchResultsViewController()
    
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
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
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
        guard let parent = parent as? WalletViewController else {
            return
        }
        searchBoxView.textField.resignFirstResponder()
        DispatchQueue.main.async(execute: parent.dismissSearch)
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
        let windowHeight = AppDelegate.current.mainWindow.bounds.height
        keyboardPlaceholderHeightConstraint.constant = windowHeight - endFrame.origin.y
        view.layoutIfNeeded()
    }
    
}
