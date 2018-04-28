import UIKit

class TransferTypeView: BottomSheetView {

    @IBOutlet weak var tableView: UITableView!

    @IBOutlet weak var tableHeightConstraint: NSLayoutConstraint!

    private weak var textfield: UITextField?

    private var assets: [AssetItem]!
    private var asset: AssetItem?
    private var callback: ((AssetItem) -> Void)?

    func presentPopupControllerAnimated(textfield: UITextField, assets: [AssetItem], asset: AssetItem?, callback: @escaping ((AssetItem) -> Void)) {
        super.presentPopupControllerAnimated()
        self.textfield = textfield
        self.asset = asset
        self.callback = callback
        if let assetId = asset?.assetId {
            self.assets = assets.sorted(by: { (pre, next) -> Bool in
                return pre.assetId == assetId
            })
        } else {
            self.assets = assets
        }
        let hiddenAssets = WalletUserDefault.shared.hiddenAssets
        self.assets = self.assets.filter({ (asset) -> Bool in
            return hiddenAssets[asset.assetId] == nil
        })
        if assets.count < 3 {
            tableHeightConstraint.constant = TransferTypeCell.cellHeight * CGFloat(assets.count)
            popupView.layoutIfNeeded()
        }
        prepareTableView()
    }

    @IBAction func cancelAction(_ sender: Any) {
        dismissPopupControllerAnimated()
    }

    override func dismissPopupControllerAnimated() {
        super.dismissPopupControllerAnimated()
        textfield?.becomeFirstResponder()
    }

    class func instance() -> TransferTypeView {
        return Bundle.main.loadNibNamed("TransferTypeView", owner: nil, options: nil)?.first as! TransferTypeView
    }
}

extension TransferTypeView: UITableViewDelegate, UITableViewDataSource {

    private func prepareTableView() {
        tableView.register(UINib(nibName: "TransferTypeCell", bundle: nil), forCellReuseIdentifier: TransferTypeCell.cellIdentifier)
        tableView.tableFooterView = UIView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = TransferTypeCell.cellHeight
        tableView.reloadData()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return assets.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TransferTypeCell.cellIdentifier) as! TransferTypeCell
        let asset = assets[indexPath.row]
        if asset.assetId == self.asset?.assetId {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        cell.render(asset: assets[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        callback?(assets[indexPath.row])
        dismissPopupControllerAnimated()
    }
}


