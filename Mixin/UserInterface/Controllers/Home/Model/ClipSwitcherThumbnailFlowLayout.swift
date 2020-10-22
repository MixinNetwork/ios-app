import UIKit

class ClipSwitcherThumbnailFlowLayout: UICollectionViewLayout {
    
    /*
     +-------+----------+----------+
     |       | Column 0 | Column 1 |
     +-------+----------+----------+
     | Row 0 |     1    |     2    |
     +-------+----------+----------+
     | Row 1 |     3    |     4    |
     +-------+----------+----------+
     */
    
    let numberOfRows: Int
    let numberOfColumns: Int
    let interitemSpacing: CGFloat
    let lineSpacing: CGFloat
    let pageInset: UIEdgeInsets
    
    private var cache: [UICollectionViewLayoutAttributes] = []
    private var contentSize: CGSize = .zero
    
    init(numberOfRows: Int, numberOfColumns: Int, interitemSpacing: CGFloat, lineSpacing: CGFloat, pageInset: UIEdgeInsets) {
        self.numberOfRows = numberOfRows
        self.numberOfColumns = numberOfColumns
        self.interitemSpacing = interitemSpacing
        self.lineSpacing = lineSpacing
        self.pageInset = pageInset
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var collectionViewContentSize: CGSize {
        contentSize
    }
    
    override func invalidateLayout() {
        super.invalidateLayout()
        cache = []
    }
    
    override func prepare() {
        guard cache.isEmpty, let collectionView = collectionView else {
            return
        }
        
        // Supports only 1 section currently
        assert(collectionView.numberOfSections == 1)
        
        guard collectionView.numberOfItems(inSection: 0) > 0 else {
            return
        }
        let columnsWidth = collectionView.bounds.width
            - collectionView.contentInset.horizontal
            - pageInset.horizontal
            - lineSpacing * (CGFloat(numberOfColumns) - 1)
        let cellWidth = floor(columnsWidth / CGFloat(numberOfColumns))
        let rowsHeight = collectionView.bounds.height
            - collectionView.contentInset.vertical
            - pageInset.vertical
            - interitemSpacing * (CGFloat(numberOfRows) - 1)
        let cellHeight = floor(rowsHeight / CGFloat(numberOfRows))
        let pageWidth = collectionView.contentInset.horizontal
            + pageInset.horizontal
            + lineSpacing * CGFloat(numberOfColumns - 1)
            + cellWidth * CGFloat(numberOfColumns)
        
        for item in 0..<collectionView.numberOfItems(inSection: 0) {
            let pageIndex = item / (numberOfRows * numberOfColumns)
            let rowIndex = (item / numberOfColumns) % numberOfRows
            let columnIndex = item % numberOfColumns // of the page
            
            let x = CGFloat(pageIndex) * pageWidth
                + collectionView.contentInset.left
                + pageInset.left
                + CGFloat(columnIndex) * (cellWidth + interitemSpacing)
            let y = collectionView.contentInset.top
                + pageInset.top
                + CGFloat(rowIndex) * (cellHeight + lineSpacing)
            
            let indexPath = IndexPath(item: item, section: 0)
            let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            let frame = CGRect(x: x, y: y, width: cellWidth, height: cellHeight)
            attributes.frame = frame
            cache.append(attributes)
            
            contentSize = CGSize(width: pageWidth * CGFloat(pageIndex + 1),
                                 height: max(contentSize.height, frame.maxY))
        }
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let attributes = cache.filter { (attributes) -> Bool in
            attributes.frame.intersects(rect)
        }
        return attributes
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        cache[indexPath.item]
    }
    
}
