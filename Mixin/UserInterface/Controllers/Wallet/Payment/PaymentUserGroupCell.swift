import UIKit
import MixinServices

protocol PaymentUserGroupCellDelegate: AnyObject {
    func paymentUserGroupCellHeightDidUpdate(_ cell: PaymentUserGroupCell)
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
        networkSwitchViewContentSizeObserver = collectionView.observe(\.contentSize, options: [.new]) { [weak self] (_, change) in
            guard let newValue = change.newValue, let self else {
                return
            }
            collectionViewHeightConstraint.constant = newValue.height
            DispatchQueue.main.async { // XXX: Doesn't work without dispatching
                self.delegate?.paymentUserGroupCellHeightDidUpdate(self)
            }
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
        cell.avatarImageView.setImage(with: user)
        cell.usernameLabel.text = "\(user.fullName) (\(user.identityNumber))"
        return cell
    }
    
}
