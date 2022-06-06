import UIKit
import MixinServices

class PreviewWallpaperViewController: UIViewController {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var tableView: ConversationTableView!
    @IBOutlet weak var collectionView: UICollectionView!
    
    private let customWallpaperIndex = 1
    
    private var customImage: UIImage?
    private var conversationId: String?
    private var wallpapers = [Wallpaper]()
    private var mockViewModels = [String: [MessageViewModel]]()
    private var selectedIndex: Int = 0 {
        didSet {
            changeWallpaper(fromIndex: oldValue, toIndex: selectedIndex)
        }
    }
    
    private lazy var imagePicker = ImagePickerController(initialCameraPosition: .front,
                                                         cropImageAfterPicked: false,
                                                         parent: self,
                                                         delegate: self)
    
    class func instance(conversationId: String? = nil) -> UIViewController {
        let vc = R.storyboard.setting.preview_wallpaper()!
        vc.conversationId = conversationId
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.background_preview())
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initWallpapers()
        buildMockModels()
        collectionView.reloadData()
        container?.rightButton.isEnabled = true
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateImage(at: selectedIndex)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            collectionView.reloadData()
            collectionView.selectItem(at: IndexPath(item: selectedIndex, section: 0), animated: false, scrollPosition: .centeredHorizontally)
        }
    }
    
}

extension PreviewWallpaperViewController: ContainerViewControllerDelegate {
    
    func barRightButtonTappedAction() {
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        DispatchQueue.global().async { [weak self] in
            guard let self = self else {
                hud.hide()
                return
            }
            if self.isCustomWallpaper(at: self.selectedIndex) {
                if let image = self.customImage {
                    Wallpaper.setCustom(image, key: self.conversationId)
                } else {
                    assertionFailure("No way custom image is nil when setting custom wallpaper")
                }
            } else {
                Wallpaper.setBuildIn(self.wallpapers[self.selectedIndex - 1], key: self.conversationId)
            }
            DispatchQueue.main.async {
                hud.hide()
                self.navigationController?.popViewController(animated: true)
            }
        }
    }
    
    func textBarRightButton() -> String? {
        R.string.localizable.set()
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
        return ConversationDateHeaderView.height
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
            cell.imageView.image = nil
            cell.iconView.isHidden = false
        } else {
            cell.imageView.image = image(at: indexPath.item)
            cell.iconView.isHidden = true
        }
        cell.updateUI(isSelected: indexPath.row == selectedIndex)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: false)
        if indexPath.item == 0 {
            imagePicker.presentPhoto()
        } else {
            selectedIndex = indexPath.item
        }
    }
    
}

extension PreviewWallpaperViewController: ImagePickerControllerDelegate {
    
    func imagePickerController(_ controller: ImagePickerController, didPickImage image: UIImage) {
        collectionView.performBatchUpdates {
            self.customImage = image
            if !self.wallpapers.contains(.custom) {
                self.wallpapers.insert(.custom, at: 0)
            }
            self.collectionView.reloadItems(at: [IndexPath(item: self.customWallpaperIndex, section: 0)])
        } completion: { _ in
            self.selectedIndex = self.customWallpaperIndex
        }
    }
    
}

extension PreviewWallpaperViewController {
    
    private func buildMockModels() {
        let messages = [(userId: myUserId, content: R.string.localizable.how_are_you()), (userId: "2", content: R.string.localizable.i_am_good())].map {
            MessageItem(messageId: UUID().uuidString,
                        conversationId: UUID().uuidString,
                        userId: $0,
                        category: MessageCategory.PLAIN_TEXT.rawValue,
                        content: $1,
                        status: MessageStatus.DELIVERED.rawValue,
                        createdAt: Date().toUTCString())
        }
        let factory = MessageViewModelFactory()
        mockViewModels = factory.viewModels(with: messages, fits: UIScreen.main.bounds.width).viewModels
    }
    
    private func initWallpapers() {
        let wallpaper = Wallpaper.get(for: conversationId)
        if wallpaper == .custom {
            wallpapers = Wallpaper.allCases
            customImage = Wallpaper.image(for: conversationId)
            selectedIndex = customWallpaperIndex
        } else {
            wallpapers = Wallpaper.defaultWallpapers
            selectedIndex = (wallpapers.firstIndex(of: wallpaper) ?? 0) + 1
        }
    }
    
    private func changeWallpaper(fromIndex: Int, toIndex: Int) {
        [(index: fromIndex, isSelected: false), (index: toIndex, isSelected: true)].forEach {
            if let cell = collectionView.cellForItem(at: IndexPath(item: $0, section: 0)) as? PreviewWallpaperCell {
                cell.updateUI(isSelected: $1)
            }
        }
        collectionView.scrollToItem(at: IndexPath(item: toIndex, section: 0), at: .centeredHorizontally, animated: true)
        updateImage(at: toIndex)
    }
    
    private func updateImage(at index: Int) {
        guard let image = image(at: index) else {
            return
        }
        let isImageUndersized = imageView.frame.width > image.size.width || imageView.frame.height > image.size.height
        if isImageUndersized {
            imageView.contentMode = .scaleAspectFill
        }
        UIView.transition(with: imageView, duration: 0.3, options: .transitionCrossDissolve, animations: {
            self.imageView.image = image
        }, completion: nil)
    }
    
    private func image(at index: Int) -> UIImage? {
        guard index - 1 < wallpapers.count, index > 0 else {
            return nil
        }
        if isCustomWallpaper(at: index) {
            return customImage
        } else {
            return wallpapers[index - 1].image
        }
    }
    
    private func viewModel(at index: Int) -> MessageViewModel? {
        if let models = mockViewModels.first?.value, index < models.count {
            return models[index]
        } else {
            return nil
        }
    }
    
    private func isCustomWallpaper(at index: Int) -> Bool {
        wallpapers.contains(.custom) && index == customWallpaperIndex
    }
    
}
