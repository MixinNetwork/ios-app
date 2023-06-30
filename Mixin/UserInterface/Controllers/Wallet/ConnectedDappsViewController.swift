import UIKit
import Combine
import Web3Wallet
import MixinServices

final class ConnectedDappsViewController: AuthorizationsViewController<ConnectedDappsContentViewController> {
    
    private var isDataLoaded = false
    private var subscribes = Set<AnyCancellable>()
    
    class func instance() -> UIViewController {
        let authorizations = ConnectedDappsViewController(nibName: R.nib.authorizationsView.name, bundle: nil)
        return ContainerViewController.instance(viewController: authorizations, title: R.string.localizable.connected_dapps())
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        networkIndicatorView.stopAnimating()
        networkIndicatorTopConstraint.constant = networkIndicatorHeightConstraint.constant
        searchBoxView.textField.placeholder = R.string.localizable.search_placeholder_dapp()
    }
    
    override func reloadData() {
        WalletConnectService.shared.$sessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                self?.contentViewController.sessions = sessions
            }
            .store(in: &subscribes)
        contentViewController.sessions = WalletConnectService.shared.sessions
        isDataLoaded = true
        search(searchBoxView.textField)
    }
    
    override func updateViews(with keyword: String) {
        if keyword.isEmpty {
            contentContainerView.bringSubviewToFront(contentViewController.view)
        } else {
            let results = contentViewController.sessions.filter { (session) -> Bool in
                session.name.contains(keyword) || session.host.contains(keyword)
            }
            searchContentViewController.sessions = results
            if isDataLoaded {
                searchContentViewController.tableView.checkEmpty(dataCount: results.count,
                                                                 text: R.string.localizable.no_results(),
                                                                 photo: R.image.emptyIndicator.ic_search_result()!)
            }
            contentContainerView.bringSubviewToFront(searchContentViewController.view)
        }
    }
    
}
