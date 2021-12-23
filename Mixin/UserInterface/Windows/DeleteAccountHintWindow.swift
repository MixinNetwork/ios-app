import UIKit
import MixinServices

final class DeleteAccountHintWindow: BottomSheetView {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var tableViewHeightConstraint: NSLayoutConstraint!
    
    var onViewWallet: (() -> Void)?
    var onContinue: (() -> Void)?
    
    private var assets = [AssetItem]()
    private let cellHeight: CGFloat = 66
    private let maxTableHeight: CGFloat = 198
    
    class func instance() -> DeleteAccountHintWindow {
        return R.nib.deleteAccountHintWindow(owner: self)!
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        tableView.register(R.nib.assetCell)
        tableView.tableFooterView = UIView()
        tableView.dataSource = self
        tableView.delegate = self
    }
    
    func render(assets: [AssetItem]) {
        self.assets = assets
        tableViewHeightConstraint.constant = min(maxTableHeight, CGFloat(assets.count) * cellHeight)
        tableView.reloadData()
    }
    
    @IBAction func closeAction(_ sender: Any) {
        dismissPopupControllerAnimated()
    }
    
    @IBAction func viewWalletAction(_ sender: Any) {
        onViewWallet?()
        dismissPopupControllerAnimated()
    }
    
    @IBAction func continueAction(_ sender: Any) {
        onContinue?()
        dismissPopupControllerAnimated()
    }
    
}

extension DeleteAccountHintWindow: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return assets.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.asset, for: indexPath)!
        if indexPath.row < assets.count {
            cell.render(asset: assets[indexPath.row], showBalanceOnly: true)
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return cellHeight
    }
    
}
