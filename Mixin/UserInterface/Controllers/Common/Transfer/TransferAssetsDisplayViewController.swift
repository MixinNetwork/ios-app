import UIKit

class TransferAssetsDisplayViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    var assets = [AssetItem]()
    
    private let cellReuseId = "cell"
    
    init() {
        super.init(nibName: "TransferAssetsDisplayView", bundle: .main)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UINib(nibName: "TransferAssetSelectorCell", bundle: .main),
                           forCellReuseIdentifier: cellReuseId)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.reloadData()
    }
    
}

extension TransferAssetsDisplayViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return assets.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseId, for: indexPath) as! TransferAssetSelectorCell
        cell.render(asset: assets[indexPath.row])
        return cell
    }
    
}

extension TransferAssetsDisplayViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
}
