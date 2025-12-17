import UIKit
import MixinServices

final class AddTokenMethodSelectorViewController: PopupSelectorViewController {
    
    enum Method: CaseIterable {
        case trade
        case deposit
    }
    
    protocol Delegate: AnyObject {
        func addTokenMethodSelectorViewController(
            _ viewController: AddTokenMethodSelectorViewController,
            didPickMethod method: Method
        )
    }
    
    weak var delegate: Delegate?
    
    private let token: any OnChainToken
    
    init(token: any OnChainToken) {
        self.token = token
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = R.color.background_quaternary()
        titleView.backgroundColor = R.color.background_quaternary()
        titleView.titleLabel.text = R.string.localizable.add_token(token.symbol)
        titleView.subtitleLabel.text = token.depositNetworkName
        tableViewTopConstraint.constant = 6
        tableView.backgroundColor = R.color.background_quaternary()
        tableView.estimatedRowHeight = 72
        tableView.rowHeight = UITableView.automaticDimension
        tableView.register(R.nib.addTokenMethodCell)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.contentInsetAdjustmentBehavior = .always
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 38, right: 0)
    }
    
}

extension AddTokenMethodSelectorViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Method.allCases.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.add_token_method, for: indexPath)!
        switch Method.allCases[indexPath.row] {
        case .trade:
            cell.iconImageView.image = R.image.filter_swap()
            cell.titleLabel.text = R.string.localizable.swap_token(token.symbol)
            cell.subtitleLabel.text = R.string.localizable.swap_token_description(token.symbol)
        case .deposit:
            cell.iconImageView.image = R.image.filter_deposit()
            cell.titleLabel.text = R.string.localizable.deposit_token(token.symbol)
            cell.subtitleLabel.text = R.string.localizable.deposit_token_description()
        }
        return cell
    }
    
}

extension AddTokenMethodSelectorViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let method = Method.allCases[indexPath.row]
        presentingViewController?.dismiss(animated: true) {
            self.delegate?.addTokenMethodSelectorViewController(self, didPickMethod: method)
        }
    }
    
}
