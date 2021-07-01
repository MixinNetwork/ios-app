import UIKit

protocol HomeAppsManagerDelegate: AnyObject {
    
    func didUpdateItems(on manager: HomeAppsManager)
    func didUpdate(pageCount: Int, on manager: HomeAppsManager)
    func didEnterEditingMode(on manager: HomeAppsManager)
    func didBeginFolderDragOut(transfer: HomeAppsDragInteractionTransfer, on manager: HomeAppsManager)
    func didSelect(app: Bot, on manager: HomeAppsManager)
    
}

class HomeAppsManager: NSObject {
    
    weak var delegate: HomeAppsManagerDelegate?
    
    unowned var viewController: UIViewController
    unowned var candidateCollectionView: UICollectionView
    unowned var pinnedCollectionView: UICollectionView? // folderVC use this manager
    var isHome: Bool
    
    var isEditing = false
    var currentPage: Int {
        guard candidateCollectionView.frame.size.width != 0 else {
            return 0
        }
        return Int(candidateCollectionView.contentOffset.x) / Int(candidateCollectionView.frame.size.width)
    }
    var currentPageCell: BotPageCell {
        let visibleCells = candidateCollectionView.visibleCells
        if visibleCells.count == 0 {
            return candidateCollectionView.subviews[0] as! BotPageCell
        } else {
            return visibleCells[0] as! BotPageCell
        }
    }
    var mode: HomeAppsMode {
        return isHome ? .regular : .folder
    }
    var items: [[BotItem]] {
        didSet {
            delegate?.didUpdate(pageCount: items.count, on: self)
            delegate?.didUpdateItems(on: self)
        }
    }
    var pinnedItems: [BotItem] {
        didSet {
            delegate?.didUpdateItems(on: self)
        }
    }
    let feedback = UIImpactFeedbackGenerator()
    var currentDragInteraction: HomeAppsDragInteraction?
    var currentFolderInteraction: HomeAppsFolderInteraction?
    var openFolderInfo: HomeAppsOpenFolderInfo?

    var pageTimer: Timer?
    var folderTimer: Timer?
    var folderRemovalTimer: Timer?
    
    var ignoreDragOutOnTop = false
    var ignoreDragOutOnBottom = false
    
    var longPressRecognizer = UILongPressGestureRecognizer()
    let tapRecognizer = UITapGestureRecognizer()
    
    init(isHome: Bool, viewController: UIViewController, candidateCollectionView: UICollectionView, pinnedCollectionView: UICollectionView? = nil) {
        self.isHome = isHome
        self.viewController = viewController
        self.candidateCollectionView = candidateCollectionView
        self.pinnedCollectionView = pinnedCollectionView
        
        items = [
            [Bot(id: "1", name: "1"), Bot(id: "2", name: "2"), Bot(id: "3", name: "3"), Bot(id: "4", name: "4"), Bot(id: "44", name: "44"),
             BotFolder(id: "111", name: "111", pages: [
                [Bot(id: "1111", name: "1111"), Bot(id: "2222", name: "22222"), Bot(id: "3333", name: "33333"), Bot(id: "4444", name: "44444"),  Bot(id: "5555", name: "55555"),  Bot(id: "6666", name: "66666"),  Bot(id: "7777", name: "77777"),  Bot(id: "8888", name: "88888"),  Bot(id: "9999", name: "99999")]
             ])],
            [Bot(id: "5", name: "5"), Bot(id: "6", name: "6"), Bot(id: "7", name: "7"), Bot(id: "8", name: "8"), Bot(id: "13", name: "13")]
        ]
        pinnedItems = [Bot(id: "9", name: "9"), Bot(id: "10", name: "10"), Bot(id: "11", name: "11"), Bot(id: "12", name: "12")]
        
        super.init()
        
        self.candidateCollectionView.dataSource = self
        self.candidateCollectionView.delegate = self
        
        self.pinnedCollectionView?.dataSource = self
        self.pinnedCollectionView?.delegate = self
        
        longPressRecognizer.addTarget(self, action: #selector(handleLongPressGesture(_:)))
        self.viewController.view.addGestureRecognizer(longPressRecognizer)
        tapRecognizer.addTarget(self, action: #selector(handleTapGesture))
        self.viewController.view.addGestureRecognizer(tapRecognizer)
    }
    
}

extension HomeAppsManager {
    
    @objc func handleTapGesture() {
        guard isEditing else {
            return
        }
        leaveEditingMode()
    }
    
    func touchedViewInfos(at point: CGPoint) -> (collectionView: UICollectionView, cell: BotPageCell, itemSize: CGSize) {
        let collectionView: UICollectionView
        var itemSize: CGSize
        if let pinnedCollectionView = pinnedCollectionView, pinnedCollectionView.frame.contains(viewController.view.convert(point, to: pinnedCollectionView)) {
            collectionView = pinnedCollectionView
            itemSize = HomeAppsMode.pinned.itemSize
        } else {
            collectionView = candidateCollectionView
            itemSize = HomeAppsMode.regular.itemSize
        }
        if !isHome {
            itemSize = HomeAppsMode.folder.itemSize
        }
        let convertedPoint = viewController.view.convert(point, to: collectionView)
        if let indexPath = collectionView.indexPathForItem(at: convertedPoint), let cell = collectionView.cellForItem(at: indexPath) as? BotPageCell {
            return (collectionView, cell, itemSize)
        } else {
            return (collectionView, collectionView.visibleCells[0] as! BotPageCell, itemSize)
        }
    }
    
    func enterEditingMode(suppressHaptic: Bool = false) {
        guard !isEditing else { return }
        isEditing = true
        if !suppressHaptic {
            feedback.impactOccurred()
        }
        for cell in candidateCollectionView.visibleCells + (pinnedCollectionView?.visibleCells ?? []) {
            if let cell = cell as? BotPageCell {
                cell.enterEditingMode()
            }
        }
        if items[items.count - 1].count > 0 {
            items.append([])
            candidateCollectionView.insertItems(at: [IndexPath(item: items.count - 1, section: 0)])
        }
        delegate?.didEnterEditingMode(on: self)
    }
    
    func leaveEditingMode() {
        guard isEditing else { return }
        isEditing = false
        for cell in candidateCollectionView.visibleCells + (pinnedCollectionView?.visibleCells ?? []) {
            if let cell = cell as? BotPageCell {
                cell.leaveEditingMode()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if self.items[self.items.count - 1].count == 0 {
                self.items.removeLast()
                self.candidateCollectionView.deleteItems(at: [IndexPath(item: self.items.count, section: 0)])
            }
        }
    }
    
    func updateState(forPageCell pageCell: BotPageCell) {
        var collectionView: UICollectionView
        if let pinnedCollectionView = pinnedCollectionView, pinnedCollectionView.visibleCells.contains(pageCell) {
            collectionView = pinnedCollectionView
        } else {
            collectionView = candidateCollectionView
        }
        var items: [BotItem] = []
        for i in 0..<pageCell.collectionView.visibleCells.count {
            let indexPath = IndexPath(item: i, section: 0)
            if let cell = pageCell.collectionView.cellForItem(at: indexPath) as? BotItemCell, let item = cell.item {
                items.append(item)
            }
        }
        if collectionView == candidateCollectionView {
            guard let pageIndexPath = collectionView.indexPath(for: pageCell) else {
                return
            }
            self.items[pageIndexPath.row] = items
        } else {
            pinnedItems = items
        }
        pageCell.items = items
    }
    
    // moves last item in page to next and rearranges next pages if needed
    func moveLastItem(inPage page: Int) {
        var currentPageItems = items[page + 1]
        currentPageItems.insert(items[page].removeLast(), at: 0)
        items[page + 1] = currentPageItems
        if currentPageItems.count >  mode.appsPerPage {
            moveLastItem(inPage: page + 1)
        }
    }
    
    func perform(transfer: HomeAppsDragInteractionTransfer) {
        viewController.view.removeGestureRecognizer(longPressRecognizer)
        
        longPressRecognizer = transfer.gestureRecognizer
        longPressRecognizer.removeTarget(nil, action: nil)
        longPressRecognizer.addTarget(self, action: #selector(handleLongPressGesture(_:)))
        viewController.view.addGestureRecognizer(longPressRecognizer)
        
        currentDragInteraction = transfer.interaction.copy()
        currentDragInteraction?.needsUpdate = true
        UIApplication.shared.keyWindow!.addSubview(transfer.interaction.liftView)
    }
    
}

extension HomeAppsManager: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == candidateCollectionView {
            return items.count
        } else {
            return 1
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let items = collectionView == candidateCollectionView ? items[indexPath.row] : pinnedItems
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.bot_page, for: indexPath)!
        cell.items = items
        cell.draggedItem = currentDragInteraction?.item
        cell.delegate = self
        cell.collectionView.reloadData()
        if pinnedCollectionView == nil {
            cell.mode = .folder
        } else {
            cell.mode = collectionView == candidateCollectionView ? .regular : .pinned
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? BotPageCell else {
            return
        }
        if let currentInteraction = currentDragInteraction, currentInteraction.needsUpdate {
            cell.items = items[indexPath.row]
            currentInteraction.currentPageCell = cell
            currentInteraction.currentIndexPath = IndexPath(item: cell.collectionView(cell.collectionView, numberOfItemsInSection: 0) - 1, section: 0)
            currentInteraction.needsUpdate = false
        }
        cell.draggedItem = currentDragInteraction?.item
        cell.collectionView.reloadData()
        if isEditing {
            cell.enterEditingMode()
        } else {
            cell.leaveEditingMode()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? BotPageCell else {
            return
        }
        if isEditing {
            cell.leaveEditingMode()
        }
    }
    
}

// MARK: - Page cell delegate

extension HomeAppsManager: BotPageCellDelegate {
    
    func didSelect(cell: BotItemCell, on pageCell: BotPageCell) {
        if let cell = cell as? BotFolderCell {
            showFolder(from: cell)
        } else if let item = cell.item as? Bot, !isEditing {
            delegate?.didSelect(app: item, on: self)
        }
    }
    
}
