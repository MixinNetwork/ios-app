import UIKit
import MixinServices

protocol TradeOrderTokenFilterPickerViewControllerDelegate: AnyObject {
    
    func tradeOrderTokenFilterPickerViewController(
        _ controller: TradeOrderTokenFilterPickerViewController,
        didPickTokens tokens: [TradeOrder.Token]
    )
    
}

final class TradeOrderTokenFilterPickerViewController: TransactionHistoryTokenFilterPickerViewController<TradeOrder.Token> {
    
    weak var delegate: TradeOrderTokenFilterPickerViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        collectionView.dataSource = self
        queue.addOperation {
            let allTokens = TokenDAO.shared.tradeOrderTokens()
                + Web3TokenDAO.shared.tradeOrderTokens()
            var assetIDs: Set<String> = []
            let tokens = allTokens.filter { token in
                assetIDs.insert(token.assetID).inserted
            }
            DispatchQueue.main.sync {
                self.tokens = tokens
                self.tableView.reloadData()
                self.reloadTableViewSelections()
            }
        }
    }
    
    override func reset(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
        delegate?.tradeOrderTokenFilterPickerViewController(self, didPickTokens: [])
    }
    
    override func apply(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
        delegate?.tradeOrderTokenFilterPickerViewController(self, didPickTokens: selectedTokens)
    }
    
}

extension TradeOrderTokenFilterPickerViewController: UITableViewDataSource {
    
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

extension TradeOrderTokenFilterPickerViewController: UICollectionViewDataSource {
    
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
