import UIKit
import PhotosUI
import MixinServices

class PreviewWallpaperViewController: UIViewController {
    
    @IBOutlet weak var wallpaperImageView: WallpaperImageView!
    @IBOutlet weak var tableView: ConversationTableView!
    @IBOutlet weak var collectionView: UICollectionView!
    
    private let mockViewModels: [String: [MessageViewModel]] = {
        let contents = [
            (userId: myUserId, content: R.string.localizable.how_are_you()),
            (userId: "2", content: R.string.localizable.i_am_good())
        ]
        let messages = contents.map { (userId, content) in
            MessageItem(messageId: UUID().uuidString,
                        conversationId: UUID().uuidString,
                        userId: userId,
                        category: MessageCategory.PLAIN_TEXT.rawValue,
                        content: content,
                        status: MessageStatus.DELIVERED.rawValue,
                        createdAt: Date().toUTCString())
        }
        let factory = MessageViewModelFactory()
        return factory.viewModels(with: messages, fits: UIScreen.main.bounds.width).viewModels
    }()
    
    private var scope: Wallpaper.Scope = .global
    private var wallpapers = Wallpaper.official
    
    class func instance(scope: Wallpaper.Scope) -> UIViewController {
        let vc = R.storyboard.setting.preview_wallpaper()!
        vc.scope = scope
        return vc
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.background_preview()
        navigationItem.rightBarButtonItem = .button(
            title: R.string.localizable.set(),
            target: self,
            action: #selector(setWallpaper(_:))
        )
        let wallpaper = Wallpaper.wallpaper(for: scope)
        let index: Int
        switch wallpaper {
        case .custom:
            wallpapers.insert(wallpaper, at: 0)
            index = 0
        default:
            index = wallpapers.firstIndex(where: wallpaper.matches(_:)) ?? 0
        }
        collectionView.reloadData()
        let indexPath = indexPath(for: index)
        collectionView.selectItem(at: indexPath, animated: false, scrollPosition: .centeredHorizontally)
        loadImage(for: indexPath)
    }
    
    @objc private func setWallpaper(_ sender: Any) {
        guard let indexPath = collectionView.indexPathsForSelectedItems?.first else {
            return
        }
        let index = wallpaperIndex(from: indexPath)
        Wallpaper.save(wallpapers[index], for: scope)
        navigationController?.popViewController(animated: true)
    }
    
}

extension PreviewWallpaperViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let models = mockViewModels.first?.value {
            return models.count
        } else {
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let viewModel = viewModel(at: indexPath.row) else {
            return self.tableView.dequeueReusableCell(withReuseId: .unknown, for: indexPath)
        }
        let cell = self.tableView.dequeueReusableCell(withMessage: viewModel.message, for: indexPath)
        if let cell = cell as? MessageCell {
            CATransaction.performWithoutAnimation {
                cell.render(viewModel: viewModel)
                cell.layoutIfNeeded()
            }
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if let model = viewModel(at: indexPath.row) {
            return model.cellHeight
        } else {
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        ConversationDateHeaderView.height
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: ConversationTableView.ReuseId.header.rawValue) as! ConversationDateHeaderView
        if let date = mockViewModels.keys.first {
            header.label.text = DateFormatter.yyyymmdd.date(from: date)?.chatTimeAgo()
        }
        return header
    }
    
}

extension PreviewWallpaperViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        wallpapers.count + 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.preview_wallpaper, for: indexPath)!
        if indexPath.item == 0 {
            cell.wallpaperImageView.isHidden = true
            cell.pickFromPhotosImageView.isHidden = false
        } else {
            let index = wallpaperIndex(from: indexPath)
            cell.wallpaperImageView.wallpaper = wallpapers[index]
            cell.wallpaperImageView.isHidden = false
            cell.pickFromPhotosImageView.isHidden = true
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        if indexPath.item == 0 {
            var config = PHPickerConfiguration(photoLibrary: .shared())
            config.selectionLimit = 1
            config.filter = .images
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = self
            present(picker, animated: true, completion: nil)
            return false
        } else {
            return true
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        loadImage(for: indexPath)
    }
    
}

extension PreviewWallpaperViewController: PHPickerViewControllerDelegate {
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.presentingViewController?.dismiss(animated: true)
        guard let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) else {
            return
        }
        provider.loadObject(ofClass: UIImage.self) { [weak self] (image, error) in
            DispatchQueue.main.async {
                if let image = image as? UIImage {
                    self?.loadCustomWallpaper(image: image)
                } else {
                    showAutoHiddenHud(style: .error, text: R.string.localizable.failed())
                }
            }
        }
    }
    
}

extension PreviewWallpaperViewController {
    
    private func viewModel(at index: Int) -> MessageViewModel? {
        if let models = mockViewModels.first?.value, index < models.count {
            return models[index]
        } else {
            return nil
        }
    }
    
    private func wallpaperIndex(from indexPath: IndexPath) -> Int {
        indexPath.item - 1
    }
    
    private func indexPath(for wallpaperIndex: Int) -> IndexPath {
        IndexPath(item: wallpaperIndex + 1, section: 0)
    }
    
    private func loadImage(for indexPath: IndexPath) {
        collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
        let index = wallpaperIndex(from: indexPath)
        let wallpaper = wallpapers[index]
        UIView.transition(with: wallpaperImageView, duration: 0.3, options: .transitionCrossDissolve, animations: {
            self.wallpaperImageView.wallpaper = wallpaper
        }, completion: nil)
    }
    
    private func loadCustomWallpaper(image: UIImage) {
        let new: Wallpaper = .custom(image)
        if wallpapers.first?.matches(new) ?? false {
            wallpapers[0] = new
        } else {
            wallpapers.insert(new, at: 0)
        }
        collectionView.reloadData()
        let indexPath = indexPath(for: 0)
        collectionView.selectItem(at: indexPath, animated: false, scrollPosition: .centeredHorizontally)
        loadImage(for: indexPath)
    }
    
}
