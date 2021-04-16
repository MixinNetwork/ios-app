import UIKit
import MixinServices

class AuthorizationsViewController: UIViewController {
    
    @IBOutlet weak var searchBoxView: SearchBoxView!
    @IBOutlet weak var networkIndicatorTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var networkIndicatorHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var networkIndicatorView: ActivityIndicatorView!
    @IBOutlet weak var contentContainerView: UIView!
    
    private var contentViewController: AuthorizationsContentViewController!
    private var isDataLoaded = false
    
    private lazy var searchContentViewController: AuthorizationsContentViewController = {
        let controller = R.storyboard.setting.authorizations_content()!
        addChild(controller)
        contentContainerView.addSubview(controller.view)
        controller.view.snp.makeEdgesEqualToSuperview()
        controller.didMove(toParent: self)
        return controller
    }()
    
    class func instance() -> UIViewController {
        let vc = R.storyboard.setting.authorization()!
        return ContainerViewController.instance(viewController: vc, title: Localized.SETTING_AUTHORIZATIONS)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchBoxView.textField.addTarget(self, action: #selector(search(_:)), for: .editingChanged)
        searchBoxView.textField.placeholder = R.string.localizable.search_placeholder_authorization()
        searchBoxView.textField.rightViewMode = .always
        view.layoutIfNeeded()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadData()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if let destination = segue.destination as? AuthorizationsContentViewController {
            contentViewController = destination
        }
    }
    
    @objc private func search(_ textField: UITextField) {
        guard textField.markedTextRange == nil else {
            return
        }
        let keyword = (textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if keyword.isEmpty {
            contentContainerView.bringSubviewToFront(contentViewController.view)
        } else {
            let results = contentViewController.authorizations.filter { (auth) -> Bool in
                auth.app.name.lowercased().contains(keyword) || auth.app.appNumber.contains(keyword)
            }
            searchContentViewController.authorizations = results
            if isDataLoaded {
                searchContentViewController.tableView.checkEmpty(dataCount: results.count,
                                                                 text: R.string.localizable.no_result(),
                                                                 photo: R.image.emptyIndicator.ic_search_result()!)
            }
            contentContainerView.bringSubviewToFront(searchContentViewController.view)
        }
    }
    
    private func reloadData() {
        AuthorizeAPI.authorizations { [weak self] (result) in
            switch result {
            case let .success(response):
                if let self = self {
                    self.contentViewController.authorizations = response
                    self.networkIndicatorView.stopAnimating()
                    self.networkIndicatorTopConstraint.constant = self.networkIndicatorHeightConstraint.constant
                    UIView.animate(withDuration: 0.25, animations: self.view.layoutIfNeeded)
                    self.contentViewController.tableView.checkEmpty(dataCount: response.count,
                                                                    text: R.string.localizable.setting_no_authorizations(),
                                                                    photo: R.image.emptyIndicator.ic_authorization()!)
                    self.isDataLoaded = true
                    self.search(self.searchBoxView.textField)
                }
            case let .failure(error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
        }
    }
    
}
