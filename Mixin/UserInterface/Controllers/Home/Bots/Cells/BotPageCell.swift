import UIKit

protocol BotPageCellDelegate: AnyObject {
    
    func didSelect(cell: BotItemCell, on pageCell: BotPageCell)
    
}

class BotPageCell: UICollectionViewCell {
    
    weak var delegate: BotPageCellDelegate?
    @IBOutlet weak var collectionView: UICollectionView!
    var mode: HomeAppsMode = .regular {
        didSet {
            updateLayout()
        }
    }
    var items: [BotItem] = []
    var draggedItem: BotItem?
    private var isEditing = false
    
    func enterEditingMode() {
        guard !isEditing else { return }
        isEditing = true
        for cell in collectionView.visibleCells {
            guard let cell = cell as? BotItemCell else { return }
            cell.startShaking()
            if let cell = cell as? BotFolderCell {
                cell.moveToFirstAvailablePage()
            }
        }
    }
    
    func leaveEditingMode() {
        guard isEditing else { return }
        isEditing = false
        for cell in collectionView.visibleCells {
            guard let cell = cell as? BotItemCell else { return }
            cell.stopShaking()
            if let cell = cell as? BotFolderCell {
                cell.leaveEditingMode()
                cell.move(to: 0, animated: true)
            }
        }
    }
    
    func delete(item: BotItem) {
        guard let index = items.firstIndex(where: { $0 === item }),
              let cell = collectionView.cellForItem(at: IndexPath(item: index, section: 0)) else {
            return
        }
        UIView.animate(withDuration: 0.25, animations: {
            cell.contentView.transform = CGAffineTransform.identity.scaledBy(x: 0.0001, y: 0.0001)
        }, completion: { _ in
            self.items.remove(at: index)
            self.collectionView.performBatchUpdates({
                self.collectionView.deleteItems(at: [IndexPath(item: index, section: 0)])
            }, completion: { _ in
                cell.contentView.transform = .identity
            })
        })
    }
    
}

extension BotPageCell {
    
    private func updateLayout() {
        guard let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else {
            return
        }
        flowLayout.itemSize = mode.itemSize
        flowLayout.minimumInteritemSpacing = mode.minimumInteritemSpacing
        flowLayout.minimumLineSpacing = mode.minimumLineSpacing
        flowLayout.sectionInset = mode.sectionInset
    }
    
}

extension BotPageCell: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard indexPath.item < items.count else {
            return UICollectionViewCell(frame: .zero)
        }
        if let botFolder = items[indexPath.item] as? BotFolder {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.bot_folder, for: indexPath)!
            cell.item = botFolder
            if isEditing {
                cell.startShaking()
                cell.moveToFirstAvailablePage(animated: false)
            } else {
                cell.stopShaking()
                cell.leaveEditingMode()
            }
            if let draggedItem = draggedItem, draggedItem === botFolder {
                cell.contentView.isHidden = true
            } else {
                cell.contentView.isHidden = false
            }
            return cell
        } else if let botItem = items[indexPath.item] as? Bot {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.bot_item, for: indexPath)!
            cell.item = botItem
            if isEditing {
                cell.startShaking()
            } else {
                cell.stopShaking()
            }
            if let draggedItem = draggedItem, draggedItem === botItem {
                cell.contentView.isHidden = true
            } else {
                cell.contentView.isHidden = false
            }
            cell.label?.isHidden = mode == .pinned
            return cell
        }
        return UICollectionViewCell(frame: .zero)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) else {
            return
        }
        delegate?.didSelect(cell: cell as! BotItemCell, on: self)
    }
    
}
