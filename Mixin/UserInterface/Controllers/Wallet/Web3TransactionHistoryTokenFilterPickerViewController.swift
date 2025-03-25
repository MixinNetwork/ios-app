import UIKit
import MixinServices

protocol Web3TransactionHistoryTokenFilterPickerViewControllerDelegate: AnyObject {
    
    func web3TransactionHistoryTokenFilterPickerViewController(
        _ controller: Web3TransactionHistoryTokenFilterPickerViewController,
        didPickTokens tokens: [Web3TokenItem]
    )
    
}

final class Web3TransactionHistoryTokenFilterPickerViewController: TransactionHistoryTokenFilterPickerViewController<Web3TokenItem> {
    
    weak var delegate: Web3TransactionHistoryTokenFilterPickerViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        collectionView.dataSource = self
        queue.addOperation {
            let tokens = Web3TokenDAO.shared.allTokens()
            DispatchQueue.main.sync {
                self.tokens = tokens
                self.tableView.reloadData()
                self.reloadTableViewSelections()
            }
        }
    }
    
    override func reset(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
        delegate?.web3TransactionHistoryTokenFilterPickerViewController(self, didPickTokens: [])
    }
    
    override func apply(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
        delegate?.web3TransactionHistoryTokenFilterPickerViewController(self, didPickTokens: selectedTokens)
    }
    
}

extension Web3TransactionHistoryTokenFilterPickerViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tokenModels.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.checkmark_token, for: indexPath)!
        let token = tokenModels[indexPath.row]
        cell.load(web3Token: token)
        return cell
    }
    
}

extension Web3TransactionHistoryTokenFilterPickerViewController: UICollectionViewDataSource {
    
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
