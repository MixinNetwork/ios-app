import UIKit
import MixinServices

protocol MixinTransactionHistoryTokenFilterPickerViewControllerDelegate: AnyObject {
    
    func mixinTransactionHistoryTokenFilterPickerViewController(
        _ controller: MixinTransactionHistoryTokenFilterPickerViewController,
        didPickTokens tokens: [MixinTokenItem]
    )
    
}

final class MixinTransactionHistoryTokenFilterPickerViewController: TransactionHistoryTokenFilterPickerViewController<MixinTokenItem> {
    
    weak var delegate: MixinTransactionHistoryTokenFilterPickerViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        collectionView.dataSource = self
        queue.addOperation {
            let tokens = TokenDAO.shared.allTokens()
            DispatchQueue.main.sync {
                self.tokens = tokens
                self.tableView.reloadData()
                self.reloadTableViewSelections()
            }
        }
    }
    
    override func reset(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
        delegate?.mixinTransactionHistoryTokenFilterPickerViewController(self, didPickTokens: [])
    }
    
    override func apply(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
        delegate?.mixinTransactionHistoryTokenFilterPickerViewController(self, didPickTokens: selectedTokens)
    }
    
}

extension MixinTransactionHistoryTokenFilterPickerViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tokenModels.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.checkmark_token, for: indexPath)!
        let token = tokenModels[indexPath.row]
        cell.load(token: token)
        return cell
    }
    
}

extension MixinTransactionHistoryTokenFilterPickerViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        selectedTokens.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: selectedTokenReuseIdentifier, for: indexPath) as! SelectedTokenCell
        let token = selectedTokens[indexPath.row]
        cell.load(token: token)
        cell.delegate = self
        return cell
    }
    
}
