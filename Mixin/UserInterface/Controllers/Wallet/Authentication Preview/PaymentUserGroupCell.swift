import UIKit
import MixinServices

protocol PaymentUserGroupCellDelegate: AnyObject {
    func paymentUserGroupCell(_ cell: PaymentUserGroupCell, didSelectMessengerUser item: UserItem)
}

final class PaymentUserGroupCell: UITableViewCell {
    
    @IBOutlet weak var captionLabel: UILabel!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionViewHeightConstraint: NSLayoutConstraint!
    
    weak var delegate: PaymentUserGroupCellDelegate?
    
    var users: [UserItem] = [] {
        didSet {
            collectionView.reloadData()
        }
    }
    
    private var networkSwitchViewContentSizeObserver: NSKeyValueObservation?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        collectionView.register(R.nib.paymentUserCell)
        collectionView.dataSource = self
        collectionView.delegate = self
        networkSwitchViewContentSizeObserver = collectionView.observe(\.contentSize, options: [.new]) { [weak self] (_, change) in
            guard let newValue = change.newValue, let self else {
                return
            }
            self.collectionViewHeightConstraint.constant = newValue.height
            self.invalidateIntrinsicContentSize()
        }
    }
    
}

extension PaymentUserGroupCell: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        users.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.payment_user, for: indexPath)!
        let user = users[indexPath.item]
        let badgeImage = user.badgeImage
        cell.avatarImageView.setImage(with: user)
        cell.usernameLabel.text = "\(user.fullName) (\(user.identityNumber))"
        cell.badgeImageView.image = badgeImage
        cell.badgeImageView.isHidden = badgeImage == nil
        return cell
    }
    
}

extension PaymentUserGroupCell: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let user = users[indexPath.item]
        if user.isCreatedByMessenger {
            delegate?.paymentUserGroupCell(self, didSelectMessengerUser: user)
        }
    }
    
}
