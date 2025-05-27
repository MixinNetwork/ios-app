import UIKit
import MixinServices

final class MembershipViewController: UIViewController {
    
    private weak var tableView: UITableView!
    
    private let plan: User.Membership.Plan
    private let expiredAt: Date
    private let emptyCellReuseIdentifier = "e"
    
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
        tableView.register(R.nib.membershipCell)
        tableView.register(R.nib.insetGroupedTitleCell)
        tableView.register(R.nib.membershipInvoiceCell)
        tableView.register(
            UITableViewCell.self,
            forCellReuseIdentifier: emptyCellReuseIdentifier
        )
        view.addSubview(tableView)
        tableView.snp.makeEdgesEqualToSuperview()
        self.tableView = tableView
        tableView.dataSource = self
        tableView.delegate = self
        SafeAPI.membershipOrders { result in
            switch result {
            case .success(let orders):
                self.orders = orders
                self.tableView.reloadData()
            case .failure(let error):
                break
            }
        }
    }
    
    @objc private func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController()
        present(customerService, animated: true)
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
                let cell = tableView.dequeueReusableCell(withIdentifier: emptyCellReuseIdentifier, for: indexPath)
                cell.backgroundConfiguration = .groupedCell
                cell.contentConfiguration = {
                    var content = cell.defaultContentConfiguration()
                    content.text = R.string.localizable.view_all()
                    content.textProperties.alignment = .center
                    content.textProperties.font = .scaledFont(ofSize: 14, weight: .regular)
                    content.textProperties.color = R.color.theme()!
                    return content
                }()
                return cell
            }
        }
    }
    
}

extension MembershipViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch Section(rawValue: section)! {
        case .plan:
                .leastNormalMagnitude
        case .invoices:
                .leastNormalMagnitude
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        nil
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section)! {
        case .plan:
            break
        case .invoices:
            switch indexPath.row {
            case 0:
                break
            case 1...orders.count:
                let order = orders[indexPath.row - 1]
                let viewController = MembershipOrderViewController(order: order)
                navigationController?.pushViewController(viewController, animated: true)
            default:
                break
            }
        }
    }
    
}

extension MembershipViewController: MembershipCell.Delegate {
    
    func membershipCellDidSelectViewPlan(_ cell: MembershipCell) {
        let plans = MembershipPlansViewController()
        present(plans, animated: true)
    }
    
}

extension MembershipViewController {
    
    private enum Section: Int, CaseIterable {
        case plan
        case invoices
    }
    
}
