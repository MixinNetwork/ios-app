import UIKit

class TransferAssetSelectorViewController: UIViewController, TransferContextAccessible {
    
    @IBOutlet weak var tableView: UITableView!
    
    var assets = [AssetItem]()
    
    private let cellReuseId = "cell"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.reloadData()
    }
    
}

extension TransferAssetSelectorViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return assets.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseId, for: indexPath) as! TransferAssetSelectorCell
        cell.render(asset: assets[indexPath.row])
        return cell
    }
    
}

extension TransferAssetSelectorViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        context?.asset = assets[indexPath.row]
        navigationController?.popViewController(animated: true)
    }
    
}
