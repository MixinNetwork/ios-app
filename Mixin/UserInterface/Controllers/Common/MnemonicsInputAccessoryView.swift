import UIKit
import MixinServices

final class MnemonicsInputAccessoryView: UIView {
    
    protocol Delegate: AnyObject {
        func mnemonicsInputAccessoryView(_ view: MnemonicsInputAccessoryView, didSelect word: String)
    }
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionViewLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var contentBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var contentLeadingConstraint: NSLayoutConstraint!
    @IBOutlet weak var contentTrailingConstraint: NSLayoutConstraint!
    
    weak var textField: UITextField?
    weak var delegate: Delegate?
    
    private var words: [String] = []
    
    override var intrinsicContentSize: CGSize {
        if #available(iOS 26, *) {
            return CGSize(width: UIView.noIntrinsicMetric, height: 54)
        } else {
            return CGSize(width: UIView.noIntrinsicMetric, height: 46)
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        if #available(iOS 26, *) {
            backgroundColor = .clear
            collectionView.backgroundColor = R.color.keyboard_background_14()
            collectionView.layer.masksToBounds = true
            contentBottomConstraint.constant = 8
            contentLeadingConstraint.constant = 8
            contentTrailingConstraint.constant = 8
        }
        collectionViewLayout.estimatedItemSize = CGSize(width: 84, height: 46)
        collectionViewLayout.itemSize = UICollectionViewFlowLayout.automaticSize
        collectionView.register(R.nib.mnemonicPhraseCell)
        collectionView.dataSource = self
        collectionView.delegate = self
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if #available(iOS 26, *) {
            collectionView.layer.cornerRadius = collectionView.frame.height / 2
        }
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
