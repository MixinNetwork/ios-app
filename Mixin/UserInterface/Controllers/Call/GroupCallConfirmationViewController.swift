import UIKit
import MixinServices

class GroupCallConfirmationViewController: CallViewController {
    
    private var members = [UserItem]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setFunctionSwitchesHidden(true)
        setConnectionButtonsEnabled(true)
        minimizeButton.setImage(R.image.ic_title_close(), for: .normal)
        minimizeButton.tintColor = .white
        inviteButton.isHidden = true
        singleUserStackView.isHidden = true
        multipleUserCollectionView.isHidden = false
        statusLabel.text = nil
        acceptTitleLabel.text = nil
        hangUpStackView.alpha = 0
        acceptStackView.alpha = 1
        acceptButtonTrailingConstraint.priority = .defaultLow
        acceptButtonCenterXConstraint.priority = .defaultHigh
        multipleUserCollectionView.dataSource = self
    }
    
    override func minimizeAction(_ sender: Any) {
        CallService.shared.dismissCallingInterface()
    }
    
    override func acceptAction(_ sender: Any) {
        // TODO
    }
    
    func loadMembers(with userIds: [String]) {
        DispatchQueue.global().async {
            let members = userIds.compactMap(UserDAO.shared.getUser(userId:))
            DispatchQueue.main.async {
                guard self.isViewLoaded else {
                    return
                }
                self.members = members
                self.multipleUserCollectionView.reloadData()
            }
        }
    }
    
}

extension GroupCallConfirmationViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        members.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.group_call_member, for: indexPath)!
        let member = members[indexPath.row]
        cell.avatarImageView.setImage(with: member)
        return cell
    }
    
}
