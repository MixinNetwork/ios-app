import UIKit

class EmergencyContactSelectorViewController: UserItemPeerViewController<PeerCell> {
    
    private var pin: String!
    
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
        guard let navigationController = navigationController else {
            return
        }
        let hud = self.hud
        hud.show(style: .busy, text: "", on: navigationController.view)
        let identityNumber = user(at: indexPath).identityNumber
        EmergencyAPI.shared.createContact(identityNumber: identityNumber, pin: pin) { [weak self] (result) in
            print(result)
            switch result {
            case .success(let response):
                hud.hide()
                if let weakSelf = self {
                    let vc = CreateEmergencyContactVerificationCodeViewController()
                    vc.identityNumber = identityNumber
                    vc.id = response.id
                    weakSelf.navigationController?.pushViewController(vc, animated: true)
                }
            case .failure(let error):
                hud.set(style: .error, text: error.localizedDescription)
                hud.scheduleAutoHidden()
            }
        }
    }
    
}
