import UIKit
import MixinServices

protocol PaymentUserGroupCellDelegate: AnyObject {
    func paymentUserGroupCell(_ cell: PaymentUserGroupCell, didSelectMessengerUser item: UserItem)
}

final class PaymentUserGroupCell: UITableViewCell {
    
    enum CheckmarkCondition {
        case never
        case byUserID(Set<String>)
    }
    
    @IBOutlet weak var contentStackView: UIStackView!
    @IBOutlet weak var captionLabel: UILabel!
    
    weak var delegate: PaymentUserGroupCellDelegate?
    
    private var users: [UserItem] = []
    private var checkmarkCondition: CheckmarkCondition = .never
    
    private weak var collectionView: UICollectionView!
    private weak var collectionViewHeightConstraint: NSLayoutConstraint!
    
    private var collectionViewContentSizeObserver: NSKeyValueObservation?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        var configuration = UICollectionLayoutListConfiguration(appearance: .plain)
        configuration.backgroundColor = R.color.background()
        configuration.showsSeparators = false
        let layout: UICollectionViewCompositionalLayout = .list(using: configuration)
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.isScrollEnabled = false
        contentStackView.addArrangedSubview(collectionView)
        let collectionViewHeightConstraint = collectionView.heightAnchor.constraint(equalToConstant: 32)
        collectionViewHeightConstraint.isActive = true
        collectionView.register(R.nib.paymentUserCell)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionViewContentSizeObserver = collectionView.observe(\.contentSize, options: [.new]) { [weak self] (_, change) in
            guard let newValue = change.newValue, let self else {
                return
            }
            // Dispatch to break an infinite loop on iOS 14
            DispatchQueue.main.async {
                UIView.performWithoutAnimation {
                    self.collectionViewHeightConstraint.constant = newValue.height
                    self.invalidateIntrinsicContentSize()
                }
            }
        }
        self.collectionView = collectionView
        self.collectionViewHeightConstraint = collectionViewHeightConstraint
    }
    
    func reloadUsers(with users: [UserItem], checkmarkCondition: CheckmarkCondition) {
        self.users = users
        self.checkmarkCondition = checkmarkCondition
        collectionView.reloadData()
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
        cell.usernameLabel.text = user.fullName
        cell.identityNumberLabel.text = "(\(user.identityNumber))"
        cell.badgeImageView.image = badgeImage
        cell.badgeImageView.isHidden = badgeImage == nil
        switch checkmarkCondition {
        case .never:
            cell.checkmark = nil
        case .byUserID(let ids):
            cell.checkmark = ids.contains(user.userId) ? .yes : .no
        }
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
