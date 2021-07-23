import UIKit

class StickerStoreBannerView: UICollectionReusableView {
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        collectionView.decelerationRate = .fast
    }
    
}

extension StickerStoreBannerView: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 3
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.sticker_preview, for: indexPath)!
        cell.backgroundColor = UIColor(red: .random(in: 0...1),
                                       green: .random(in: 0...1),
                                       blue: .random(in: 0...1),
                                       alpha: 1.0)
        return cell
    }
    
}
