import UIKit
import MixinServices

final class AllMembershipOrdersViewController: UIViewController {
    
    private let headerReuseIdentifier = "h"
    
    private var orders: [MembershipOrder] = []
    
    init(orders: [MembershipOrder]) {
        self.orders = orders
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.all_invoices()
        let tableView = UITableView(frame: view.bounds, style: .insetGrouped)
        tableView.backgroundColor = R.color.background_secondary()
        tableView.alwaysBounceVertical = true
        tableView.estimatedRowHeight = 62
        tableView.separatorStyle = .none
        tableView.sectionHeaderHeight = .leastNormalMagnitude
        tableView.sectionFooterHeight = .leastNormalMagnitude
        tableView.sectionHeaderTopPadding = 10
        tableView.register(R.nib.membershipInvoiceCell)
        tableView.register(
            MembershipOrdersHeaderView.self,
            forHeaderFooterViewReuseIdentifier: headerReuseIdentifier
        )
        view.addSubview(tableView)
        tableView.snp.makeEdgesEqualToSuperview()
        tableView.dataSource = self
        tableView.delegate = self
        DispatchQueue.global().async { [weak self, weak tableView] in
            let orders = MembershipOrderDAO.shared.orders(limit: nil)
            DispatchQueue.main.async {
                guard let self, let tableView else {
                    return
                }
                self.orders = orders
                tableView.reloadData()
            }
        }
    }
    
}

extension AllMembershipOrdersViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .secondaryBackground
    }
    
}

extension AllMembershipOrdersViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        orders.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.membership_invoice, for: indexPath)!
        let order = orders[indexPath.row]
        cell.load(order: order)
        return cell
    }
    
}

extension AllMembershipOrdersViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let order = orders[indexPath.row]
        let viewController = MembershipOrderViewController(order: order)
        navigationController?.pushViewController(viewController, animated: true)
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        nil
    }
    
}
