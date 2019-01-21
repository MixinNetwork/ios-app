import UIKit
import GiphyCoreSDK

class GiphySearchViewController: UIViewController {
    
    @IBOutlet weak var dismissButton: UIButton!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var keywordTextField: UITextField!
    @IBOutlet weak var collectionView: UICollectionView!
    
    weak var conversationViewController: ConversationViewController?
    
    var onDisappear: (() -> Void)?
    
    override var modalPresentationStyle: UIModalPresentationStyle {
        get {
            return .overCurrentContext
        }
        set {
            
        }
    }
    
    private let cellReuseId = "cell"
    private let loadingFooterReuseId = "loading"
    private let noResultFooterReuseId = "no_result"
    private let giphyPoweredFooterReuseId = "giphy"
    private let limit = 24

    private var status = Status.loading
    private var urls = [GiphyImageURL]()
    private var isLoadingMore = false
    private var animated: Bool = false {
        didSet {
            for case let cell as AnimatedImageCollectionViewCell in collectionView.visibleCells {
                cell.imageView.autoPlayAnimatedImage = animated
                if animated {
                    cell.imageView.startAnimating()
                } else {
                    cell.imageView.stopAnimating()
                }
            }
        }
    }
    
    private var collectionViewLayout: GiphyCollectionViewFlowLayout? {
        return collectionView.collectionViewLayout as? GiphyCollectionViewFlowLayout
    }
    
    private weak var lastGiphyOperation: Operation?
    
    private lazy var reloadHandler = { [weak self] (response: GPHListMediaResponse?, error: Error?) in
        guard let weakSelf = self, let data = response?.data else {
            return
        }
        let urls = data.compactMap(GiphyImageURL.init)
        DispatchQueue.main.async {
            weakSelf.status = urls.isEmpty ? .noResult : .loading
            weakSelf.urls = urls
            weakSelf.collectionView.reloadData()
        }
    }
    private lazy var loadMoreHandler = { [weak self] (response: GPHListMediaResponse?, error: Error?) in
        guard let weakSelf = self, let data = response?.data else {
            return
        }
        let urls = data.compactMap(GiphyImageURL.init)
        DispatchQueue.main.async {
            if urls.isEmpty {
                weakSelf.status = .noMoreResult
                weakSelf.collectionView.reloadData()
            } else {
                let indexPaths = (weakSelf.urls.count..<(weakSelf.urls.count + urls.count))
                    .map({ IndexPath(row: $0, section: 0) })
                weakSelf.urls.append(contentsOf: urls)
                weakSelf.collectionView.insertItems(at: indexPaths)
            }
        }
    }
    
    class func instance() -> GiphySearchViewController {
        return Storyboard.chat.instantiateViewController(withIdentifier: "giphy_search") as! GiphySearchViewController
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        keywordTextField.delegate = self
        collectionView.keyboardDismissMode = .onDrag
        collectionView.register(AnimatedImageCollectionViewCell.self,
                                forCellWithReuseIdentifier: cellReuseId)
        collectionView.register(UINib(nibName: "LoadingIndicatorFooterView", bundle: .main),
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
                                withReuseIdentifier: loadingFooterReuseId)
        collectionView.register(UINib(nibName: "NoResultFooterView", bundle: .main),
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
                                withReuseIdentifier: noResultFooterReuseId)
        collectionView.register(UINib(nibName: "GiphyPoweredFooterView", bundle: .main),
                                forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
                                withReuseIdentifier: giphyPoweredFooterReuseId)
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
        lastGiphyOperation?.cancel()
        self.animated = false
        onDisappear?()
    }
    
    @IBAction func dismissAction(_ sender: Any) {
        UIView.animate(withDuration: 0.5) {
            self.conversationViewController?.dismissPanelsButton.alpha = 0
        }
        dismiss(animated: true, completion: nil)
    }
    
    func prepareForReuse() {
        guard isViewLoaded else {
            return
        }
        keywordTextField.text = nil
        reload()
    }
    
}

extension GiphySearchViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        lastGiphyOperation?.cancel()
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
        return urls.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellReuseId, for: indexPath) as! AnimatedImageCollectionViewCell
        cell.imageView.contentMode = .scaleAspectFill
        let url = urls[indexPath.row].preview
        cell.imageView.sd_setImage(with: url, completed: nil)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        return collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: footerReuseId, for: indexPath)
    }
    
}

extension GiphySearchViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let url = urls[indexPath.row].fullsized
        conversationViewController?.dataSource?.sendGif(at: url)
        conversationViewController?.reduceStickerPanelHeightIfMaximized()
        dismissAction(collectionView)
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? AnimatedImageCollectionViewCell else {
            return
        }
        if animated {
            cell.imageView.autoPlayAnimatedImage = true
            cell.imageView.startAnimating()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? AnimatedImageCollectionViewCell else {
            return
        }
        cell.imageView.autoPlayAnimatedImage = false
        cell.imageView.stopAnimating()
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplaySupplementaryView view: UICollectionReusableView, forElementKind elementKind: String, at indexPath: IndexPath) {
        guard !urls.isEmpty && elementKind == UICollectionView.elementKindSectionFooter && lastGiphyOperation == nil else {
            return
        }
        if let keyword = keywordTextField.text, !keyword.isEmpty {
            lastGiphyOperation = GiphyCore.shared.search(keyword, offset: urls.count, limit: limit, lang: .current, completionHandler: loadMoreHandler)
        } else {
            lastGiphyOperation = GiphyCore.shared.trending(offset: urls.count, limit: limit, completionHandler: loadMoreHandler)
        }
    }
    
}

extension GiphySearchViewController {
    
    enum Status {
        case noResult
        case loading
        case noMoreResult
    }
    
    private var footerReuseId: String {
        switch status {
        case .noResult:
            return noResultFooterReuseId
        case .loading:
            return loadingFooterReuseId
        case .noMoreResult:
            return giphyPoweredFooterReuseId
        }
    }
    
    private func prepareCollectionViewForReuse() {
        status = .loading
        collectionView.setContentOffset(.zero, animated: false)
        urls = []
        collectionView.reloadData()
    }
    
    private func reload() {
        prepareCollectionViewForReuse()
        lastGiphyOperation = GiphyCore.shared.trending(limit: limit, completionHandler: reloadHandler)
    }
    
    private func search(_ keyword: String) {
        prepareCollectionViewForReuse()
        lastGiphyOperation = GiphyCore.shared.search(keyword, limit: limit, lang: .current, completionHandler: reloadHandler)
    }
    
}
