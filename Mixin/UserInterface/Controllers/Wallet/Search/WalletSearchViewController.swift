import UIKit
import MixinServices

final class WalletSearchViewController<ModelController: WalletSearchModelController>: UIViewController, SearchNavigationAnimating {
    
    private let searchBoxView = SearchBoxView()
    private let recents: WalletSearchRecentsViewController<ModelController>
    private let searchResults: WalletSearchResultsViewController<ModelController>
    
    init(modelController: ModelController) {
        self.recents = WalletSearchRecentsViewController(modelController: modelController)
        self.searchResults = WalletSearchResultsViewController(modelController: modelController)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.hidesBackButton = true
        navigationItem.titleView = searchBoxView
        navigationItem.rightBarButtonItem = .cancelSearch(
            target: self,
            action: #selector(cancelAction(_:))
        )
        searchBoxView.textField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        searchBoxView.textField.placeholder = R.string.localizable.search_placeholder_asset()
        view.backgroundColor = .background
        for child in [searchResults, recents] {
            addChild(child)
            view.addSubview(child.view)
            child.view.snp.makeConstraints { make in
                make.top.equalTo(view.safeAreaLayoutGuide)
                make.leading.trailing.bottom.equalToSuperview()
            }
            child.didMove(toParent: self)
        }
        searchResults.view.isHidden = true
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
    
    @objc private func cancelAction(_ sender: Any) {
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
            if !searchResults.view.isHidden {
                recents.collectionView.setContentOffset(.zero, animated: false)
            }
            recents.view.isHidden = false
            searchResults.view.isHidden = true
        } else {
            recents.view.isHidden = true
            searchResults.view.isHidden = false
        }
    }
    
}
