import UIKit
import MixinServices

final class MembershipOrderViewController: UIViewController {
    
    private let emptyCellReuseIdentifier = "e"
    
    private weak var tableView: UITableView!
    
    private var order: MembershipOrder
    private var rewards: MembershipOrder.StarRepresentation?
    private var rows: [Row] = []
    
    init(order: MembershipOrder) {
        self.order = order
        self.rewards = order.subscriptionRewards
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = R.string.localizable.invoice()
        navigationItem.rightBarButtonItem = .customerService(
            target: self,
            action: #selector(presentCustomerService(_:))
        )
        
        let tableView = UITableView(frame: view.bounds, style: .insetGrouped)
        tableView.backgroundColor = R.color.background_secondary()
        tableView.alwaysBounceVertical = true
        tableView.estimatedRowHeight = 62
        tableView.separatorStyle = .none
        tableView.sectionHeaderHeight = .leastNormalMagnitude
        tableView.sectionFooterHeight = .leastNormalMagnitude
        tableView.sectionHeaderTopPadding = 10
        tableView.register(R.nib.membershipOrderStatusCell)
        tableView.register(R.nib.membershipOrderInfoCell)
        tableView.register(R.nib.membershipOrderRewardsCell)
        tableView.register(
            UITableViewCell.self,
            forCellReuseIdentifier: emptyCellReuseIdentifier
        )
        view.addSubview(tableView)
        tableView.snp.makeEdgesEqualToSuperview()
        self.tableView = tableView
        tableView.dataSource = self
        tableView.delegate = self
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadOrder),
            name: MembershipOrderDAO.didUpdateNotification,
            object: nil
        )
        reloadData(order: order)
    }
    
    @objc private func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController()
        present(customerService, animated: true)
    }
    
}

extension MembershipOrderViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .secondaryBackground
    }
    
}

extension MembershipOrderViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .status:
            1
        case .infos:
            rows.count + 2
        case .rewards:
            rewards == nil ? 0 : 1
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .status:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.membership_order_status, for: indexPath)!
            cell.load(order: order)
            cell.delegate = self
            return cell
        case .infos:
            switch indexPath.row {
            case 0, rows.count + 1:
                let cell = tableView.dequeueReusableCell(withIdentifier: emptyCellReuseIdentifier, for: indexPath)
                cell.backgroundConfiguration = .groupedCell
                cell.contentConfiguration = nil
                return cell
            default:
                let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.membership_order_info, for: indexPath)!
                let row = rows[indexPath.row - 1]
                cell.titleLabel.text = row.title
                cell.contentLabel.text = row.content
                cell.iconImageView.image = row.image
                return cell
            }
        case .rewards:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.membership_order_rewards, for: indexPath)!
            if let rewards {
                cell.countLabel.text = rewards.count
                cell.unitLabel.text = rewards.unit
            }
            return cell
        }
    }
    
}

extension MembershipOrderViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch Section(rawValue: indexPath.section)! {
        case .status, .rewards:
            UITableView.automaticDimension
        case .infos:
            switch indexPath.row {
            case 0, rows.count + 1:
                10
            default:
                UITableView.automaticDimension
            }
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        nil
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }
    
}

extension MembershipOrderViewController: MembershipOrderStatusCell.Delegate {
    
    func membershipOrderStatusCellWantsToCancel(_ cell: MembershipOrderStatusCell) {
        let confirmation = CancelPendingMembershipOrderViewController(order: order)
        present(confirmation, animated: true)
    }
    
}

extension MembershipOrderViewController {
    
    private enum Section: Int, CaseIterable {
        case status
        case infos
        case rewards
    }
    
    private struct Row {
        
        let title: String
        let content: String
        let image: UIImage?
        
        init(title: String, content: String, image: UIImage? = nil) {
            self.title = title
            self.content = content
            self.image = image
        }
        
    }
    
    @objc private func reloadOrder() {
        let id = order.orderID.uuidString.lowercased()
        DispatchQueue.global().async { [weak self] in
            guard let order = MembershipOrderDAO.shared.order(id: id) else {
                return
            }
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.order = order
                self.rewards = order.subscriptionRewards
                self.reloadData(order: order)
            }
        }
    }
    
    private func reloadData(order: MembershipOrder) {
        rows = [
            Row(
                title: R.string.localizable.transaction_id().uppercased(),
                content: order.orderID.uuidString.lowercased()
            ),
        ]
        
        switch order.transition {
        case .buyStars, .none:
            break
        case .upgrade(let plan), .renew(let plan):
            let (plan, planIcon) = switch plan {
            case .basic:
                (R.string.localizable.membership_advance(), R.image.membership_advance_large())
            case .standard:
                (R.string.localizable.membership_elite(), R.image.membership_elite_large())
            case .premium:
                (R.string.localizable.membership_prosperity(), UserBadgeIcon.largeProsperityImage)
            }
            rows.append(
                Row(
                    title: R.string.localizable.membership_plan().uppercased(),
                    content: plan,
                    image: planIcon
                )
            )
        }
        
        let amount = switch order.status.knownCase {
        case .paid:
            order.actualAmount
        default:
            order.amount
        }
        let time = if let date = DateFormatter.iso8601Full.date(from: order.createdAt) {
            DateFormatter.dateFull.string(from: date)
        } else {
            order.createdAt
        }
        rows.append(contentsOf: [
            Row(
                title: R.string.localizable.amount().uppercased(),
                content: "USD " + amount
            ),
            Row(
                title: R.string.localizable.time().uppercased(),
                content: time
            ),
        ])
        
        tableView.reloadData()
    }
    
}
