import UIKit
import MixinServices

final class InscriptionTraitsCell: UITableViewCell {
    
    @IBOutlet weak var captionLabel: UILabel!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionViewLayout: LeftAlignedCollectionViewFlowLayout!
    @IBOutlet weak var collectionViewHeightConstraint: NSLayoutConstraint!
    
    var traits: [InscriptionItem.NameValueTrait] = [] {
        didSet {
            collectionView.reloadData()
        }
    }
    
    private var contentSizeObserver: NSKeyValueObservation?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        captionLabel.text = R.string.localizable.collectible_traits()
        collectionViewLayout.sectionInset = UIEdgeInsets(top: 9, left: 0, bottom: 10, right: 0)
        collectionViewLayout.minimumInteritemSpacing = 12
        collectionViewLayout.minimumLineSpacing = 12
        collectionView.register(R.nib.inscriptionTraitCell)
        collectionView.dataSource = self
        contentSizeObserver = collectionView.observe(\.contentSize, options: [.new]) { [weak self] (_, change) in
            guard let newValue = change.newValue, let self else {
                return
            }
            self.collectionViewHeightConstraint.constant = newValue.height
            self.invalidateIntrinsicContentSize()
        }
    }
    
}

extension InscriptionTraitsCell: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        traits.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.inscription_trait, for: indexPath)!
        let trait = traits[indexPath.item]
        cell.nameLabel.text = trait.name.uppercased()
        cell.valueLabel.text = trait.value
        return cell
    }
    
}
