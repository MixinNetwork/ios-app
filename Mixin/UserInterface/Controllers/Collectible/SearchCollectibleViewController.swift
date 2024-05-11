import UIKit
import MixinServices

final class SearchCollectibleViewController: UIViewController {
    
    @IBOutlet weak var searchBoxView: SearchBoxView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionViewLayout: LeftAlignedCollectionViewFlowLayout!
    
    private let interitemSpacing: CGFloat = 15
    private let queue = OperationQueue()
    private let initDataOperation = BlockOperation()
    
    private var lastLayoutWidth: CGFloat?
    private var searchResults: [InscriptionItem] = []
    private var lastKeyword: String?
    
    init() {
        let nib = R.nib.searchCollectibleView
        super.init(nibName: nib.name, bundle: nib.bundle)
        queue.maxConcurrentOperationCount = 1
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchBoxView.textField.placeholder = R.string.localizable.search_placeholder_inscription()
        searchBoxView.textField.addTarget(self, action: #selector(searchKeyword(_:)), for: .editingChanged)
        searchBoxView.textField.becomeFirstResponder()
        
        collectionViewLayout.minimumInteritemSpacing = interitemSpacing
        collectionViewLayout.minimumLineSpacing = 15
        collectionViewLayout.sectionInset = UIEdgeInsets(top: 20, left: 20, bottom: 0, right: 20)
        collectionView.register(R.nib.collectibleCell)
        collectionView.dataSource = self
        collectionView.delegate = self
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let width = view.bounds.width
        - view.safeAreaInsets.horizontal
        - collectionViewLayout.sectionInset.horizontal
        if lastLayoutWidth != width {
            lastLayoutWidth = width
            let itemWidth = floor((width - interitemSpacing) / 2)
            let itemHeight = ceil(itemWidth / 160 * 216)
            collectionViewLayout.itemSize = CGSize(width: itemWidth, height: itemHeight)
            collectionViewLayout.invalidateLayout()
        }
    }
    
    @IBAction func cancelSearching(_ sender: Any) {
        searchBoxView.textField.resignFirstResponder()
        (parent as? CollectiblesViewController)?.cancelSearching()
    }
    
    @objc private func searchKeyword(_ sender: Any) {
        guard let keyword = searchBoxView.spacesTrimmedText?.lowercased() else {
            cancelSearchOperations()
            lastKeyword = nil
            searchBoxView.isBusy = false
            reloadData(with: [])
            return
        }
        guard keyword != lastKeyword else {
            searchBoxView.isBusy = false
            return
        }
        cancelSearchOperations()
        let op = BlockOperation()
        op.addExecutionBlock { [unowned op] in
            usleep(200 * 1000)
            guard !op.isCancelled else {
                return
            }
            let searchResults = InscriptionDAO.shared.search(keyword: keyword)
            DispatchQueue.main.sync {
                guard !op.isCancelled else {
                    return
                }
                self.lastKeyword = keyword
                self.reloadData(with: searchResults)
                self.searchBoxView.isBusy = false
            }
        }
        queue.addOperation(op)
        searchBoxView.isBusy = true
    }
    
    private func cancelSearchOperations() {
        for operation in queue.operations {
            operation.cancel()
        }
    }
    
    private func reloadData(with searchResults: [InscriptionItem]) {
        self.searchResults = searchResults
        collectionView.reloadData()
        collectionView.checkEmpty(dataCount: searchResults.count,
                                  text: R.string.localizable.no_results(),
                                  photo: R.image.emptyIndicator.ic_search_result()!)
    }
    
}

extension SearchCollectibleViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        searchResults.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.collectible, for: indexPath)!
        let item = searchResults[indexPath.item]
        if let url = item.imageContentURL {
            cell.contentImageView.image = nil
            cell.contentImageView.contentMode = .scaleAspectFill
            cell.contentImageView.sd_setImage(with: url)
        } else {
            cell.contentImageView.image = R.image.inscription_intaglio()
            cell.contentImageView.contentMode = .center
        }
        cell.titleLabel.text = item.collectionName
        cell.subtitleLabel.text = "#\(item.sequence)"
        return cell
    }
    
}

extension SearchCollectibleViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        let item = searchResults[indexPath.item]
        let preview = InscriptionViewController(source: .collectible(inscriptionHash: item.inscriptionHash),
                                                inscription: item,
                                                isMine: true)
        navigationController?.pushViewController(preview, animated: true)
    }
    
}
