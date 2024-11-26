import UIKit
import MixinServices

final class MnemonicsInputAccessoryView: UIView {
    
    protocol Delegate: AnyObject {
        func mnemonicsInputAccessoryView(_ view: MnemonicsInputAccessoryView, didSelect word: String)
    }
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionViewLayout: UICollectionViewFlowLayout!
    
    weak var textField: UITextField?
    weak var delegate: Delegate?
    
    private var words: [String] = []
    
    override func awakeFromNib() {
        super.awakeFromNib()
        collectionViewLayout.estimatedItemSize = CGSize(width: 84, height: 46)
        collectionViewLayout.itemSize = UICollectionViewFlowLayout.automaticSize
        collectionView.register(R.nib.mnemonicPhraseCell)
        collectionView.dataSource = self
        collectionView.delegate = self
    }
    
    func reloadData(words: [String]) {
        collectionView.isScrollEnabled = false
        collectionView.setContentOffset(.zero, animated: false)
        collectionView.isScrollEnabled = true
        self.words = words
        collectionView.reloadData()
    }
    
}

extension MnemonicsInputAccessoryView: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        words.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.mnemonic_phrase, for: indexPath)!
        cell.label.text = words[indexPath.item]
        return cell
    }
    
}

extension MnemonicsInputAccessoryView: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        delegate?.mnemonicsInputAccessoryView(self, didSelect: words[indexPath.item])
    }
    
}
