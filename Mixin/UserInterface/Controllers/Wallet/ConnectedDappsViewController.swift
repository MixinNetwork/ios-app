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
        WalletConnectService.shared.$v1Sessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                self?.contentViewController.v1Sessions = sessions
            }
            .store(in: &subscribes)
        WalletConnectService.shared.$v2Sessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                self?.contentViewController.v2Sessions = sessions
            }
            .store(in: &subscribes)
        contentViewController.v1Sessions = WalletConnectService.shared.v1Sessions
        contentViewController.v2Sessions = WalletConnectService.shared.v2Sessions
        isDataLoaded = true
        search(searchBoxView.textField)
    }
    
    override func updateViews(with keyword: String) {
        if keyword.isEmpty {
            contentContainerView.bringSubviewToFront(contentViewController.view)
        } else {
            let v1Results = contentViewController.v1Sessions.filter { (session) -> Bool in
                session.name.contains(keyword) || session.host.contains(keyword)
            }
            let v2Results = contentViewController.v2Sessions.filter { (session) -> Bool in
                session.name.contains(keyword) || session.host.contains(keyword)
            }
            searchContentViewController.v1Sessions = contentViewController.v1Sessions.filter { (session) -> Bool in
                session.name.contains(keyword) || session.host.contains(keyword)
            }
            searchContentViewController.v2Sessions = contentViewController.v2Sessions.filter { (session) -> Bool in
                session.name.contains(keyword) || session.host.contains(keyword)
            }
            if isDataLoaded {
                searchContentViewController.tableView.checkEmpty(dataCount: v1Results.count + v2Results.count,
                                                                 text: R.string.localizable.no_results(),
                                                                 photo: R.image.emptyIndicator.ic_search_result()!)
            }
            contentContainerView.bringSubviewToFront(searchContentViewController.view)
        }
    }
    
}
