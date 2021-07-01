import UIKit

class BotFolderCell: BotItemCell {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var folderWrapperView: UIView!
    
    var currentPage: Int {
        guard collectionView.frame.size.width != 0 else {
            return 0
        }
        return Int(collectionView.contentOffset.x) / Int(collectionView.frame.size.width)
    }
    
    private var placeholderView: UIView?
    private var bots: [[Bot]] = [] {
        didSet {
            self.collectionView.reloadData()
        }
    }
        
    override func updateUI() {
        super.updateUI()
        guard let folder = item as? BotFolder else {
            return
        }
        placeholderView?.removeFromSuperview()
        imageContainerView.transform = .identity
        
        bots = folder.pages
        collectionView.reloadData()
    }
    
    override func leaveEditingMode() {
        super.leaveEditingMode()
        guard let folder = item as? BotFolder, bots[bots.count - 1].count == 0 else {
            return
        }
        bots.removeLast()
        folder.pages = bots
        collectionView.reloadData()
    }
    
}

extension BotFolderCell {
    
    func moveToFirstAvailablePage(animated: Bool = true) {
        if let folder = item as? BotFolder, bots[bots.count - 1].count > 0 {
            folder.pages.append([])
            bots.append([])
        }
        let appsPerPage = 4 * (ScreenHeight.current == .medium ? 3 : 4)
        for (page, botsInPage) in bots.enumerated() {
            if botsInPage.count < appsPerPage {
                if page != currentPage {
                    move(to: page, animated: animated)
                }
                break
            }
        }
    }
    
    func move(to page: Int, animated: Bool) {
        guard page < bots.count else { return }
        let indexPath = IndexPath(item: page, section: 0)
        collectionView.scrollToItem(at: indexPath, at: .left, animated: animated)
    }
    
    func move(view: UIView, toCellPositionAtIndex index: Int, completion: (() -> Void)? = nil) {
        guard let currentPageCell = collectionView.cellForItem(at: IndexPath(item: currentPage, section: 0)) as? BotPageCell,
              let flowLayout = currentPageCell.collectionView.collectionViewLayout as? UICollectionViewFlowLayout,
              let layoutAttributes = flowLayout.layoutAttributesForItem(at: IndexPath(item: index, section: 0)) else {
            return
        }
        // todo: ??
        if layoutAttributes.frame.minX == 0 {
            layoutAttributes.frame.origin.x = flowLayout.sectionInset.left
        }
        let convertedRect1 = convert(layoutAttributes.frame, from: currentPageCell)
        let convertedRect2 = convert(convertedRect1, to: view.superview!)
        UIView.animate(withDuration: 0.35, animations: {
            view.frame = convertedRect2
        }, completion: { _ in
            completion?()
        })
    }
    
    func revokeFolderCreation(completion: @escaping () -> Void) {
        guard let currentPageCell = collectionView.cellForItem(at: IndexPath(item: currentPage, section: 0)) as? BotPageCell,
              let botCell = currentPageCell.collectionView.cellForItem(at: IndexPath(item: 0, section: 0)) as? BotCell else {
            return
        }
        let convertedRect1 = currentPageCell.convert(botCell.imageView!.frame, from: botCell)
        let convertedRect2 = convert(convertedRect1, from: currentPageCell)
        let imageView = UIImageView(frame: convertedRect2)
        imageView.image = botCell.imageView!.image
        contentView.addSubview(imageView)
        botCell.imageView!.isHidden = true
        UIView.animate(withDuration: 0.55, animations: {
            imageView.transform = .transform(rect: imageView.frame, to: self.contentView.frame)
            self.contentView.transform = CGAffineTransform.identity.scaledBy(x: 0.01, y: 0.01)
            self.label?.alpha = 0
        }, completion: { _ in
            self.placeholderView = imageView
            botCell.imageView!.isHidden = false
            completion()
        })
    }
    
}

extension BotFolderCell: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return bots.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard indexPath.item < bots.count else {
            return UICollectionViewCell()
        }
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.bot_page, for: indexPath)!
        cell.draggedItem = nil
        cell.items = bots[indexPath.item]
        cell.collectionView.reloadData()
        cell.mode = .nestedFolder
        return cell
    }
    
}
