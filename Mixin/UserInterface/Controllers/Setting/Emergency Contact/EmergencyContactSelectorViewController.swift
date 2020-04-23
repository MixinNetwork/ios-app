import UIKit
import MixinServices

class EmergencyContactSelectorViewController: UserItemPeerViewController<PeerCell> {
    
    private var pin = ""
    
    private lazy var hud = Hud()
    
    convenience init(pin: String) {
        self.init()
        self.pin = pin
    }
    
    override func catalog(users: [UserItem]) -> (titles: [String], models: [UserItem]) {
        let contacts = users.filter { !$0.isBot }
        return ([], contacts)
    }
    
    override func configure(cell: PeerCell, at indexPath: IndexPath) {
        super.configure(cell: cell, at: indexPath)
        cell.peerInfoViewLeadingConstraint.constant = 36
        if !isSearching {
            cell.peerInfoView.descriptionLabel.text = user(at: indexPath).identityNumber
            cell.peerInfoView.descriptionLabel.isHidden = false
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let identityNumber = user(at: indexPath).identityNumber
        let alert = UIAlertController(title: R.string.localizable.emergency_confirm(identityNumber), message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: R.string.localizable.dialog_button_cancel(), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: R.string.localizable.dialog_button_confirm(), style: .default, handler: { (_) in
            self.setEmergencyContact(identityNumber: identityNumber)
        }))
        present(alert, animated: true, completion: nil)
    }

    private func setEmergencyContact(identityNumber: String) {
        guard let navigationController = navigationController else {
            return
        }
        let hud = self.hud
        hud.show(style: .busy, text: "", on: navigationController.view)
        EmergencyAPI.shared.createContact(identityNumber: identityNumber) { [weak self] (result) in
            switch result {
            case .success(let response):
                hud.hide()
                if let weakSelf = self {
                    let vc = CreateEmergencyContactVerificationCodeViewController(pin: weakSelf.pin, verificationId: response.id, identityNumber: identityNumber)
                    weakSelf.navigationController?.pushViewController(vc, animated: true)
                }
            case .failure(let error):
                hud.set(style: .error, text: error.localizedDescription)
                hud.scheduleAutoHidden()
            }
        }
    }
    
}
