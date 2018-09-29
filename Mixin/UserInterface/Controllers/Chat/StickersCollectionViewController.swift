import UIKit

class StickersCollectionViewController: UIViewController {
    
    let cellReuseId = "StickerCell"
    
    var index = NSNotFound
    
    var collectionView: UICollectionView {
        return view as! UICollectionView
    }
    
    var updateUsedAtAfterSent: Bool {
        return true
    }
    
    var isEmpty: Bool {
        return true
    }
    
    var conversationViewController: ConversationViewController? {
        return parent?.parent?.parent as? ConversationViewController
    }
    
    var animated: Bool = false {
        didSet {
            for case let cell as StickerCollectionViewCell in collectionView.visibleCells {
                cell.imageView.autoPlayAnimatedImage = animated
                if animated {
                    cell.imageView.startAnimating()
                } else {
                    cell.imageView.stopAnimating()
                }
            }
        }
    }
    
    override func loadView() {
        let frame = CGRect(x: 0, y: 0, width: 375, height: 200)
        let layout = StickersCollectionViewFlowLayout(numberOfItemsPerRow: StickerInputModelController.numberOfItemsPerRow)
        let view = UICollectionView(frame: frame, collectionViewLayout: layout)
        view.showsHorizontalScrollIndicator = false
        view.showsVerticalScrollIndicator = false
        view.backgroundColor = .white
        self.view = view
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView.register(StickerCollectionViewCell.self, forCellWithReuseIdentifier: cellReuseId)
        collectionView.dataSource = self
        collectionView.delegate = self
    }
    
}

extension StickersCollectionViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        fatalError()
    }
    
}

extension StickersCollectionViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? StickerCollectionViewCell else {
            return
        }
        if animated {
            cell.imageView.autoPlayAnimatedImage = true
            cell.imageView.startAnimating()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? StickerCollectionViewCell else {
            return
        }
        cell.imageView.autoPlayAnimatedImage = false
        cell.imageView.stopAnimating()
    }
    
}
