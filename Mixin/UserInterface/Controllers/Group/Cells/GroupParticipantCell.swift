import UIKit
import MixinServices

class GroupParticipantCell: PeerCell {
    
    override class var nib: UINib {
        return UINib(nibName: "GroupParticipantCell", bundle: .main)
    }
    
    override class var reuseIdentifier: String {
        return "group_participant"
    }
    
    @IBOutlet weak var roleLabel: UILabel!
    @IBOutlet weak var activityIndicator: ActivityIndicatorView!
    
    override func prepareForReuse() {
        super.prepareForReuse()
        roleLabel.isHidden = false
        activityIndicator.stopAnimating()
    }
    
    func startLoading() {
        roleLabel.isHidden = true
        activityIndicator.startAnimating()
    }
    
    func stopLoading() {
        roleLabel.isHidden = false
        activityIndicator.stopAnimating()
    }
    
    override func render(result: SearchResult) {
        peerInfoView.render(result: result)
        if let result = result as? UserSearchResult {
            renderUserRole(user: result.user)
        }
    }
    
    override func render(user: UserItem) {
        peerInfoView.render(user: user)
        renderUserRole(user: user)
    }
    
    private func renderUserRole(user: UserItem) {
        switch user.role {
        case ParticipantRole.ADMIN.rawValue:
            roleLabel.text = R.string.localizable.group_role_admin()
        case ParticipantRole.OWNER.rawValue:
            roleLabel.text = R.string.localizable.group_role_owner()
        default:
            roleLabel.text = ""
        }
    }
    
}
