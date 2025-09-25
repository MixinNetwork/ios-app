import UIKit
import MixinServices

final class MembershipViewController: UIViewController {
    
    private enum Section: Int, CaseIterable {
        case invite
        case plan
        case invoices
    }
    
    private weak var tableView: UITableView!
    
    private let plan: User.Membership.Plan
    private let expiredAt: Date
    private let headerReuseIdentifier = "h"
    private let maxOrdersCount = 8
    
    private var orders: [MembershipOrder] = []
    private var hasMoreOrders = false
    
    init(plan: User.Membership.Plan, expiredAt: Date) {
        self.plan = plan
        self.expiredAt = expiredAt
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = R.string.localizable.mixin_one()
        navigationItem.rightBarButtonItem = .customerService(
            target: self,
            action: #selector(presentCustomerService(_:))
        )
        
        let tableView = UITableView(frame: view.bounds, style: .insetGrouped)
        tableView.backgroundColor = R.color.background_secondary()
        tableView.alwaysBounceVertical = true
        tableView.estimatedRowHeight = 62
        tableView.separatorStyle = .none
        tableView.sectionFooterHeight = .leastNormalMagnitude
        tableView.sectionHeaderTopPadding = 10
        tableView.register(R.nib.membershipInviteCell)
        tableView.register(R.nib.membershipCell)
        tableView.register(R.nib.insetGroupedTitleCell)
        tableView.register(R.nib.membershipInvoiceCell)
        tableView.register(R.nib.membershipViewAllOrdersCell)
        tableView.register(
            MembershipOrdersHeaderView.self,
            forHeaderFooterViewReuseIdentifier: headerReuseIdentifier
        )
        view.addSubview(tableView)
        tableView.snp.makeEdgesEqualToSuperview()
        self.tableView = tableView
        tableView.dataSource = self
        tableView.delegate = self
        reloadFromLocal()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadFromLocal),
            name: MembershipOrderDAO.didUpdateNotification,
            object: nil
        )
        let reloadOrders = ReloadMembershipOrderJob()
        ConcurrentJobQueue.shared.addJob(job: reloadOrders)
    }
    
    @objc private func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController()
        present(customerService, animated: true)
    }
    
    @objc private func reloadFromLocal() {
        DispatchQueue.global().async { [limit=maxOrdersCount, weak self] in
            var orders = MembershipOrderDAO.shared.orders(limit: limit + 1)
            let hasMoreOrders: Bool
            if orders.count > limit {
                hasMoreOrders = true
                orders.removeLast()
            } else {
                hasMoreOrders = false
            }
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                let sections = IndexSet([Section.invoices.rawValue])
                self.orders = orders
                self.hasMoreOrders = hasMoreOrders
                UIView.performWithoutAnimation {
                    self.tableView.reloadSections(sections, with: .none)
                }
            }
        }
    }
    
}

extension MembershipViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .secondaryBackground
    }
    
}

extension MembershipViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .invite:
            1
        case .plan:
            1
        case .invoices:
            if orders.isEmpty {
                0
            } else {
                1 + orders.count + (hasMoreOrders ? 1 : 0)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .invite:
            return tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.membership_invite, for: indexPath)!
        case .plan:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.membership, for: indexPath)!
            cell.load(plan: plan, expiredAt: expiredAt)
            cell.delegate = self
            return cell
        case .invoices:
            switch indexPath.row {
            case 0:
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.inset_grouped_title, for: indexPath)!
                cell.label.text = R.string.localizable.invoices()
                cell.disclosureIndicatorView.isHidden = false
                return cell
            case 1...orders.count:
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.membership_invoice, for: indexPath)!
                let order = orders[indexPath.row - 1]
                cell.load(order: order)
                return cell
            default:
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.membership_view_all_orders, for: indexPath)!
                return cell
            }
        }
    }
    
}

extension MembershipViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        nil
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section)! {
        case .invite:
            let context = MixinWebViewController.Context(conversationId: "", initialUrl: .referral)
            UIApplication.homeContainerViewController?.presentWebViewController(context: context)
        case .plan:
            break
        case .invoices:
            switch indexPath.row {
            case 0:
                let allOrders = AllMembershipOrdersViewController(orders: orders)
                navigationController?.pushViewController(allOrders, animated: true)
            case 1...orders.count:
                let order = orders[indexPath.row - 1]
                let viewController = MembershipOrderViewController(order: order)
                navigationController?.pushViewController(viewController, animated: true)
            default:
                let allOrders = AllMembershipOrdersViewController(orders: orders)
                navigationController?.pushViewController(allOrders, animated: true)
            }
        }
    }
    
}

extension MembershipViewController: MembershipCell.Delegate {
    
    func membershipCellDidSelectViewPlan(_ cell: MembershipCell) {
        let plan = SafeMembership.Plan(userMembershipPlan: plan)
        let plans = MembershipPlansViewController(selectedPlan: plan)
        present(plans, animated: true)
    }
    
}
