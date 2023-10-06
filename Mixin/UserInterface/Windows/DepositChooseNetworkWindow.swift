import UIKit
import MixinServices

class DepositChooseNetworkWindow: BottomSheetView {
    
    @IBOutlet weak var tableView: UITableView!
    
    private var canDismiss = false
    private var asset: AssetItem!
    private var chain: Chain!
    
    override func dismissPopupController(animated: Bool) {
        guard canDismiss else {
            return
        }
        super.dismissPopupController(animated: animated)
    }
    
    func render(asset: AssetItem, chain: Chain) -> DepositChooseNetworkWindow {
        self.asset = asset
        self.chain = chain
        tableView.register(R.nib.depositNetworkCell)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.reloadData()
        return self
    }
    
    class func instance() -> DepositChooseNetworkWindow {
        R.nib.depositChooseNetworkWindow(withOwner: self)!
    }
    
}

extension DepositChooseNetworkWindow: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.deposit_network, for: indexPath)!
        cell.label.text = asset.depositNetworkName ?? chain.name
        cell.iconImageView.sd_setImage(with: URL(string: chain.iconUrl))
        return cell
    }
    
}

extension DepositChooseNetworkWindow: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        canDismiss = true
        dismissPopupController(animated: true)
    }
    
}
