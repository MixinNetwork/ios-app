import UIKit

final class WalletTransferSearchResultsViewController: TokenSearchResultsViewController {

    weak var transferSearchController: TransferSearchViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        activityIndicator.snp.remakeConstraints { (make) in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview()
        }
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.compact_asset, for: indexPath)!
        let item = searchResults[indexPath.row]
        cell.render(token: item, description: .balance)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let transferSearchController {
            let asset = searchResults[indexPath.row]
            transferSearchController.delegate?.transferSearchViewController(transferSearchController, didSelectToken: asset)
            transferSearchController.dismiss(animated: true)
        }
    }
    
    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        guard let endFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        let keyboardWillBeInvisible = (UIScreen.main.bounds.height - endFrame.origin.y) <= 1
        let viewHeight = view.bounds.height
        let constraint = keyboardWillBeInvisible ? viewHeight / 2 : (viewHeight - endFrame.height) / 2
        activityIndicator.snp.updateConstraints { make in
            make.top.equalToSuperview().offset(constraint)
        }
        view.layoutIfNeeded()
    }
    
}
