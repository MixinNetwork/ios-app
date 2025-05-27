import UIKit
import MixinServices

final class MembershipOrderViewController: UIViewController {
    
    private let order: MembershipOrder
    
    private var rows: [Row] = []
    
    init(order: MembershipOrder) {
        self.order = order
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
        view.addSubview(tableView)
        tableView.snp.makeEdgesEqualToSuperview()
        tableView.dataSource = self
        tableView.delegate = self
        
        let orderSource = switch order.fiatOrder?.source {
        case "app_store":
            "App Store"
        case "google_play":
            "Google Play"
        default:
            switch order.source {
            case "mixin":
                "Mixin"
            case "mixpay":
                "MixPay"
            default:
                order.source
            }
        }
        let (plan, planIcon) = switch order.after.knownCase {
        case .basic:
            (R.string.localizable.membership_advance(), R.image.membership_advance_large())
        case .standard:
            (R.string.localizable.membership_elite(), R.image.membership_elite_large())
        case .premium:
            (R.string.localizable.membership_prosperity(), UserBadgeIcon.prosperityImage(dimension: 18))
        case nil:
            (order.after.rawValue, nil)
        }
        let time = if let date = DateFormatter.iso8601Full.date(from: order.createdAt) {
            DateFormatter.dateFull.string(from: date)
        } else {
            order.createdAt
        }
        rows = [
            Row(
                title: R.string.localizable.transaction_id().uppercased(),
                content: order.orderID.uuidString.lowercased()
            ),
            Row(
                title: R.string.localizable.buy_via().uppercased(),
                content: orderSource
            ),
            Row(
                title: R.string.localizable.membership_plan().uppercased(),
                content: plan,
                image: planIcon
            ),
            Row(
                title: R.string.localizable.time().uppercased(),
                content: time
            ),
        ]
        tableView.reloadData()
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
            rows.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .status:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.membership_order_status, for: indexPath)!
            cell.load(order: order)
            return cell
        case .infos:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.membership_order_info, for: indexPath)!
            let row = rows[indexPath.row]
            cell.titleLabel.text = row.title
            cell.contentLabel.text = row.content
            cell.iconImageView.image = row.image
            return cell
        }
    }
    
}

extension MembershipOrderViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        nil
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }
    
}

extension MembershipOrderViewController {
    
    private enum Section: Int, CaseIterable {
        case status
        case infos
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
    
}
