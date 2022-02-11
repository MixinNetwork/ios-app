import UIKit

final class StackedPhotoView: UIView {
    
    var viewModels = [PhotoMessageViewModel]() {
        didSet {
            collectionView.reloadData()
        }
    }
    var cornerRadius = CGFloat(13) {
        didSet {
            guard cornerRadius != oldValue else {
                return
            }
            collectionView.reloadData()
        }
    }
    
    private let collectionView: UICollectionView!
    private let stackedPhotoLayout: StackedPhotoLayout!
    
    required init(stackedPhotoLayout: StackedPhotoLayout = StackedPhotoLayout()) {
        self.stackedPhotoLayout = stackedPhotoLayout
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: stackedPhotoLayout)
        super.init(frame: .zero)
        collectionView.backgroundColor = .clear
        collectionView.isScrollEnabled = false
        collectionView.dataSource = self
        collectionView.register(StackedPhotoCell.self, forCellWithReuseIdentifier: StackedPhotoCell.reuseIdentifier)
        addSubview(collectionView)
        collectionView.snp.makeEdgesEqualToSuperview()
        clipsToBounds = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

extension StackedPhotoView: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        min(stackedPhotoLayout.visibleItemCount, viewModels.count)
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: StackedPhotoCell.reuseIdentifier, for: indexPath) as! StackedPhotoCell
        cell.layer.cornerRadius = cornerRadius
        cell.layer.anchorPoint = CGPoint(x: 1, y: 1)
        let centerX = 0.5 * cell.bounds.width + cell.center.x
        let centerY = 0.5 * cell.bounds.height + cell.center.y
        cell.center = CGPoint(x: centerX, y: centerY)
        cell.viewModel = viewModels[indexPath.row]
        return  cell
    }
    
}
