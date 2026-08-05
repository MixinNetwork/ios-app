import UIKit

class MarketHeaderView: UICollectionReusableView {
    
    protocol Delegate: AnyObject {
        func marketHeaderView(_ view: MarketHeaderView, didSelectSubCategoryAt index: Int)
    }
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionViewLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var collectionViewHeightConstraint: NSLayoutConstraint!
    
    weak var delegate: Delegate?
    
    var subCategories: [MarketSubCategoryDisplay] = [] {
        didSet {
            collectionView.reloadData()
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        collectionViewLayout.sectionInset = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        collectionView.register(R.nib.marketSubCategoryCell)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.alwaysBounceHorizontal = true
        collectionView.showsHorizontalScrollIndicator = false
    }
    
    func selectSubCategory(at index: Int) {
        collectionView.selectItem(
            at: IndexPath(item: index, section: 0),
            animated: false,
            scrollPosition: []
        )
    }
    
}

extension MarketHeaderView: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        subCategories.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.market_sub_category, for: indexPath)!
        cell.category = subCategories[indexPath.item]
        return cell
    }
    
}

extension MarketHeaderView: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.marketHeaderView(self, didSelectSubCategoryAt: indexPath.item)
    }
    
}
