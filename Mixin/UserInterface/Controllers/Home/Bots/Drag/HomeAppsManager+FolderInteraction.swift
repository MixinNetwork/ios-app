import Foundation

extension HomeAppsManager {
    
    @discardableResult
    func showFolder(from cell: BotFolderCell, isNewFolder: Bool = false, startInRename: Bool = false) -> HomeAppsFolderViewController {
        openFolderInfo = HomeAppsOpenFolderInfo(cell: cell, isNewFolder: isNewFolder)
        cell.stopShaking()
        let convertedFrame = cell.convert(cell.contentView.frame, to: self.viewController.view)
        let folderViewController = HomeAppsFolderViewController()
        folderViewController.modalPresentationStyle = .overFullScreen
        folderViewController.isEditing = self.isEditing
        folderViewController.folder = cell.item as? BotFolder
        folderViewController.currentPage = cell.currentPage
        folderViewController.sourcePoint = convertedFrame.origin
        folderViewController.startInRename = startInRename
        folderViewController.delegate = self
        if let dragInteraction = currentDragInteraction {
            folderViewController.dragInteractionTransfer = HomeAppsDragInteractionTransfer(gestureRecognizer: longPressRecognizer, interaction: dragInteraction)
            currentDragInteraction = nil
            longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressGesture(_:)))
            viewController.view.addGestureRecognizer(longPressRecognizer)
        }
        viewController.present(folderViewController, animated: false, completion: nil)
        return folderViewController
    }
    
    func startFolderOperation(for itemCell: BotItemCell) {
        guard let dragInteraction = currentDragInteraction else { return }
        // create folder when exceed thread time
        folderTimer = Timer.scheduledTimer(timeInterval: 0.7, target: self, selector: #selector(folderTimerHandler), userInfo: nil, repeats: false)
        dragInteraction.transitionToFolderWrapperView()
        
        let folderWrapperView = UIView(frame: itemCell.imageContainerView.frame)
        folderWrapperView.layer.cornerRadius = 12
        folderWrapperView.backgroundColor = R.color.background_secondary()
        itemCell.contentView.insertSubview(folderWrapperView, belowSubview: itemCell.imageContainerView)
        
        cancelFolderOperation()
        
        if let folder = itemCell.item as? BotFolder {
            currentFolderInteraction = HomeAppsFolderDropInteraction(dragInteraction: dragInteraction, folder: folder, placeholderView: folderWrapperView)
        } else if let app = itemCell.item as? Bot {
            currentFolderInteraction = HomeAppsFolderCreationInteraction(dragInteraction: dragInteraction, destinationApp: app, wrapperView: folderWrapperView)
        }
        itemCell.stopShaking()
        UIView.animate(withDuration: 0.25) {
            folderWrapperView.transform = CGAffineTransform.identity.scaledBy(x: 1.2, y: 1.2)
            self.currentDragInteraction?.liftView.transform = .identity
            itemCell.label?.alpha = 0
        }
    }
    
    func cancelFolderOperation() {
        guard var folderInteraction = currentFolderInteraction, let index = folderInteraction.dragInteraction.currentPageCell.items.firstIndex(where: { $0 === folderInteraction.item }), let cell = folderInteraction.dragInteraction.currentPageCell.collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? BotItemCell,
            !folderInteraction.isDismissing else { return }
        
        folderInteraction.dragInteraction.transitionFromFolderWrapperView()
        folderTimer?.invalidate()
        folderTimer = nil
        currentFolderInteraction = nil
        folderInteraction.isDismissing = true
        
        UIView.animate(withDuration: 0.25, animations: {
            folderInteraction.wrapperView.transform = .identity
            self.currentDragInteraction?.liftView.transform = CGAffineTransform.identity.scaledBy(x: 1.3, y: 1.3)
            cell.label?.alpha = 1
        }, completion: { _ in
            if let folderCell = cell as? BotFolderCell {
                folderCell.folderWrapperView.isHidden = false
            }
            folderInteraction.wrapperView.removeFromSuperview()
            cell.startShaking()
        })
    }
    
    func commitFolderOperation(didDrop: Bool = false) {
        
    }
    
}

extension HomeAppsManager {
    
    @objc func folderRemoveTimerHandler() {
        
    }
    
    @objc func folderTimerHandler() {
        
    }
    
}

extension HomeAppsManager: HomeAppsFolderViewControllerDelegate {
    
}
