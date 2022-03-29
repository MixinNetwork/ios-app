import UIKit

class StackedPhotoView: UIView {
        
    var viewModels = [PhotoMessageViewModel]() {
        didSet {
            collectionView.reloadData()
        }
    }
    
    private let layout = StackedPhotoLayout()
    
    private var collectionView: UICollectionView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.isScrollEnabled = false
        collectionView.dataSource = self
        collectionView.register(StackedPhotoCell.self, forCellWithReuseIdentifier: StackedPhotoCell.reuseIdentifier)
        addSubview(collectionView)
        collectionView.snp.makeEdgesEqualToSuperview()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

extension StackedPhotoView: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        min(layout.visibleItemCount, viewModels.count)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: StackedPhotoCell.reuseIdentifier, for: indexPath) as! StackedPhotoCell
        cell.viewModel = viewModels[indexPath.row]
        DispatchQueue.main.async {
            cell.updateAnchorPoint()
        }
        return  cell
    }

}
