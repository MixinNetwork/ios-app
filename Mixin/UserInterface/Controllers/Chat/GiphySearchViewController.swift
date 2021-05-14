import UIKit
import Alamofire

class GiphySearchViewController: UIViewController {
    
    @IBOutlet weak var keywordTextField: UITextField!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionViewLayout: GiphyCollectionViewFlowLayout!
    
    weak var composer: ConversationMessageComposer?
    
    var onDisappear: (() -> Void)?
    
    private let limit = 24
    
    private var status = Status.loading
    private var images = [GiphyImage]()
    private var isLoadingMore = false
    private var animated: Bool = false {
        didSet {
            for case let cell as StickerPreviewCell in collectionView.visibleCells {
                if animated {
                    cell.stickerView.startAnimating()
                } else {
                    cell.stickerView.stopAnimating()
                }
            }
        }
    }
    
    private weak var lastGiphyRequest: DataRequest?
    
    private lazy var reloadHandler = { [weak self] (result: Result<[GiphyImage], Error>) in
        guard let weakSelf = self, case let .success(images) = result else {
            return
        }
        DispatchQueue.main.async {
            weakSelf.status = images.isEmpty ? .noResult : .loading
            weakSelf.images = images
            weakSelf.collectionView.reloadData()
        }
    }
    
    private lazy var loadMoreHandler = { [weak self] (result: Result<[GiphyImage], Error>) in
        guard let weakSelf = self, case let .success(images) = result else {
            return
        }
        DispatchQueue.main.async {
            if images.isEmpty {
                weakSelf.status = .noMoreResult
                weakSelf.collectionView.reloadData()
            } else {
                let indexPaths = (weakSelf.images.count..<(weakSelf.images.count + images.count))
                    .map({ IndexPath(row: $0, section: 0) })
                weakSelf.images.append(contentsOf: images)
                weakSelf.collectionView.insertItems(at: indexPaths)
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        transitioningDelegate = PopupPresentationManager.shared
        modalPresentationStyle = .custom
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updatePreferredContentSizeHeight()
        keywordTextField.delegate = self
        collectionView.keyboardDismissMode = .onDrag
        collectionView.register(StickerPreviewCell.self,
                                forCellWithReuseIdentifier: ReuseId.cell)
        collectionView.register(UINib(nibName: "LoadingIndicatorFooterView", bundle: .main),
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
                                withReuseIdentifier: ReuseId.Footer.loading)
        collectionView.register(UINib(nibName: "NoResultFooterView", bundle: .main),
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
                                withReuseIdentifier: ReuseId.Footer.noResult)
        collectionView.register(UINib(nibName: "GiphyPoweredFooterView", bundle: .main),
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
                                withReuseIdentifier: ReuseId.Footer.giphyPowered)
        collectionView.dataSource = self
        collectionView.delegate = self
        reload()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.animated = true
        super.viewWillAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        lastGiphyRequest?.cancel()
        self.animated = false
        onDisappear?()
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updatePreferredContentSizeHeight()
    }
    
    @IBAction func dismissAction(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
}

extension GiphySearchViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        lastGiphyRequest?.cancel()
        if let keyword = keywordTextField.text, !keyword.isEmpty {
            search(keyword)
        } else {
            reload()
        }
        return false
    }
    
}

extension GiphySearchViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return images.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ReuseId.cell, for: indexPath) as! StickerPreviewCell
        let url = images[indexPath.row].previewUrl
        cell.stickerView.load(imageURL: url, contentMode: .scaleAspectFill)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        return collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: footerReuseId, for: indexPath)
    }
    
}

extension GiphySearchViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let image = images[indexPath.row]
        let cell = collectionView.cellForItem(at: indexPath) as? StickerPreviewCell
        composer?.send(image: image, thumbnail: cell?.image)
        dismissAction(collectionView)
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? StickerPreviewCell else {
            return
        }
        if animated {
            cell.stickerView.startAnimating()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? StickerPreviewCell else {
            return
        }
        cell.stickerView.stopAnimating()
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplaySupplementaryView view: UICollectionReusableView, forElementKind elementKind: String, at indexPath: IndexPath) {
        guard !images.isEmpty && elementKind == UICollectionView.elementKindSectionFooter && lastGiphyRequest == nil else {
            return
        }
        if let keyword = keywordTextField.text, !keyword.isEmpty {
            lastGiphyRequest = GiphyAPI.search(keyword: keyword,
                                               offset: images.count,
                                               limit: limit,
                                               completion: loadMoreHandler)
        } else {
            lastGiphyRequest = GiphyAPI.trending(offset: images.count,
                                                 limit: limit,
                                                 completion: loadMoreHandler)
        }
    }
    
}

extension GiphySearchViewController {
    
    enum Status {
        case noResult
        case loading
        case noMoreResult
    }
    
    enum ReuseId {
        
        static let cell = "cell"
        
        enum Footer {
            static let loading = "loading"
            static let noResult = "no_result"
            static let giphyPowered = "giphy"
        }
        
    }
    
    private var footerReuseId: String {
        switch status {
        case .noResult:
            return ReuseId.Footer.noResult
        case .loading:
            return ReuseId.Footer.loading
        case .noMoreResult:
            return ReuseId.Footer.giphyPowered
        }
    }
    
    private func updatePreferredContentSizeHeight() {
        let window = AppDelegate.current.mainWindow
        preferredContentSize.height = window.bounds.height - window.safeAreaInsets.top - 56
    }
    
    private func prepareCollectionViewForReuse() {
        status = .loading
        collectionView.setContentOffset(.zero, animated: false)
        images = []
        collectionView.reloadData()
    }
    
    private func reload() {
        prepareCollectionViewForReuse()
        lastGiphyRequest = GiphyAPI.trending(limit: limit,
                                             completion: reloadHandler)
    }
    
    private func search(_ keyword: String) {
        prepareCollectionViewForReuse()
        lastGiphyRequest = GiphyAPI.search(keyword: keyword,
                                           limit: limit,
                                           completion: reloadHandler)
    }
    
}
