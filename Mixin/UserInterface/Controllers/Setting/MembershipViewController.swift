import UIKit
import MixinServices

final class MembershipViewController: UIViewController {
    
    private weak var tableView: UITableView!
    
    private var account: Account
    
    init(account: Account) {
        self.account = account
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItem = .customerService(
            target: self,
            action: #selector(presentCustomerService(_:))
        )
        
        let tableView = UITableView(frame: view.bounds, style: .insetGrouped)
        tableView.backgroundColor = R.color.background_secondary()
        tableView.alwaysBounceVertical = true
        tableView.estimatedRowHeight = 62
        tableView.separatorStyle = .none
        tableView.register(R.nib.membershipCell)
        view.addSubview(tableView)
        tableView.snp.makeEdgesEqualToSuperview()
        self.tableView = tableView
        tableView.dataSource = self
        tableView.delegate = self
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
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.membership, for: indexPath)!
        switch account.membership?.plan {
        case .none?, nil:
            cell.membershipLabel.text = "Advance"
            cell.viewPlanButton.isEnabled = true
        case .advance:
            cell.membershipLabel.text = "Advance"
            cell.viewPlanButton.isEnabled = false
        case .elite:
            cell.membershipLabel.text = "Elite"
            cell.viewPlanButton.isEnabled = false
        case .prosperity:
            cell.membershipLabel.text = "Prosperity"
            cell.viewPlanButton.isEnabled = false
        }
        cell.delegate = self
        return cell
    }
    
}

extension MembershipViewController: UITableViewDelegate {
    
}

extension MembershipViewController: MembershipCell.Delegate {
    
    func membershipCellDidSelectViewPlan(_ cell: MembershipCell) {
        let plans = MembershipPlansViewController()
        present(plans, animated: true)
    }
    
}
