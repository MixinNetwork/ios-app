import UIKit
import MixinServices

final class MarketTokenSelectorViewController: PopupSelectorViewController {
    
    private let name: String
    private let tokens: [TokenItem]
    private let onSelected: (Int) -> Void
    
    init(name: String, tokens: [TokenItem], onSelected: @escaping (Int) -> Void) {
        self.name = name
        self.tokens = tokens
        self.onSelected = onSelected
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleView.titleLabel.text = R.string.localizable.choose_token(name)
        titleView.subtitleLabel.text = R.string.localizable.choose_token_desc(name)
        tableView.rowHeight = 72
        tableView.register(R.nib.marketTokenSelectorCell)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 40, right: 0)
    }
    
}

extension MarketTokenSelectorViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tokens.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.market_token_selector, for: indexPath)!
        let token = tokens[indexPath.row]
        cell.tokenIconView.setIcon(token: token)
        cell.titleLabel.text = token.localizedBalanceWithSymbol
        cell.subtitleLabel.text = token.depositNetworkName
        return cell
    }
    
}

extension MarketTokenSelectorViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presentingViewController?.dismiss(animated: true) {
            self.onSelected(indexPath.row)
        }
    }
    
}
