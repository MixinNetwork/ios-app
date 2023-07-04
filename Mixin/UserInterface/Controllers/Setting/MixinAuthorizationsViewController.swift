import UIKit
import MixinServices

class MixinAuthorizationsViewController: AuthorizationsViewController<MixinAuthorizationsContentViewController> {
    
    private var isDataLoaded = false
    
    class func instance() -> UIViewController {
        let authorizations = MixinAuthorizationsViewController(nibName: R.nib.authorizationsView.name, bundle: nil)
        return ContainerViewController.instance(viewController: authorizations, title: R.string.localizable.authorizations())
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchBoxView.textField.placeholder = R.string.localizable.setting_auth_search_hint()
        view.layoutIfNeeded()
    }
    
    override func reloadData() {
        AuthorizeAPI.authorizations { [weak self] (result) in
            switch result {
            case let .success(response):
                if let self = self {
                    self.contentViewController.authorizations = response
                    self.networkIndicatorView.stopAnimating()
                    self.networkIndicatorTopConstraint.constant = self.networkIndicatorHeightConstraint.constant
                    UIView.animate(withDuration: 0.25, animations: self.view.layoutIfNeeded)
                    self.contentViewController.tableView.checkEmpty(dataCount: response.count,
                                                                    text: R.string.localizable.no_authorizations(),
                                                                    photo: R.image.emptyIndicator.ic_authorization()!)
                    self.isDataLoaded = true
                    self.search(self.searchBoxView.textField)
                }
            case let .failure(error):
                showAutoHiddenHud(style: .error, text: error.localizedDescription)
            }
        }
    }
    
    override func updateViews(with keyword: String) {
        if keyword.isEmpty {
            contentContainerView.bringSubviewToFront(contentViewController.view)
        } else {
            let results = contentViewController.authorizations.filter { (auth) -> Bool in
                auth.app.name.lowercased().contains(keyword) || auth.app.appNumber.contains(keyword)
            }
            searchContentViewController.authorizations = results
            if isDataLoaded {
                searchContentViewController.tableView.checkEmpty(dataCount: results.count,
                                                                 text: R.string.localizable.no_results(),
                                                                 photo: R.image.emptyIndicator.ic_search_result()!)
            }
            contentContainerView.bringSubviewToFront(searchContentViewController.view)
        }
    }
    
}
