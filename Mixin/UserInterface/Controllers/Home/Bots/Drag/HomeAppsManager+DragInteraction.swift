import Foundation

// MARK: - Long Press Gesture handler
extension HomeAppsManager {
    
    @objc func handleLongPressGesture(_ gestureRecognizer: UILongPressGestureRecognizer) {
        switch gestureRecognizer.state {
        case .began:
            beginDragInteraction(gestureRecognizer)
        case .changed:
            updateDragInteraction(gestureRecognizer)
        default:
            endDragInteraction(gestureRecognizer)
        }
    }
    
    private func beginDragInteraction(_ gestureRecognizer: UILongPressGestureRecognizer) {
        feedback.prepare()
        var touchPoint = gestureRecognizer.location(in: viewController.view)
        let (collectionView, pageCell) = touchedViewInfos(at: touchPoint)
        let cellSize = collectionView == candidateCollectionView ? appSize : pinnedAppSize
        guard let view = viewController.view.hitTest(touchPoint, with: nil), view.bounds.size.equalTo(cellSize) else { return }
        touchPoint = gestureRecognizer.location(in: collectionView)
        touchPoint.x -= collectionView.contentOffset.x
        
        if let indexPath = pageCell.collectionView.indexPathForItem(at: touchPoint), let cell = pageCell.collectionView.cellForItem(at: indexPath) as? BotItemCell, let item = cell.item {
            let dragOffset = CGSize(width: cell.center.x - touchPoint.x, height: cell.center.y - touchPoint.y)
            var offsettedTouchPoint = gestureRecognizer.location(in: collectionView)
            offsettedTouchPoint.x += dragOffset.width
            offsettedTouchPoint.y += dragOffset.height
            
            let liftView = cell.snapshotView
            liftView.center = viewController.view.convert(offsettedTouchPoint, from: collectionView)
            viewController.view.addSubview(liftView)
            cell.contentView.isHidden = true
            
            enterEditingMode()
            currentDragInteraction = HomeAppsDragInteraction(liftView: liftView, dragOffset: dragOffset, item: item, originalPageCell: pageCell, originalIndexPath: indexPath)
            
            UIView.animate(withDuration: 0.25, animations: {
                liftView.transform = CGAffineTransform.identity.scaledBy(x: 1.3, y: 1.3)
                liftView.alpha = 0.8
            })
        }
    }
    
    private func updateDragInteraction(_ gestureRecognizer: UILongPressGestureRecognizer) {
        var touchPoint = gestureRecognizer.location(in: viewController.view)
        guard let currentInteraction = currentDragInteraction else { return }
        let (collectionView, pageCell) = touchedViewInfos(at: touchPoint)
        touchPoint = gestureRecognizer.location(in: collectionView)
        
        let convertedTouchPoint = viewController.view.convert(touchPoint, from: collectionView)
        currentInteraction.moveLiftView(to: convertedTouchPoint)
        if currentInteraction.needsUpdate {
            return
        }
        touchPoint.x -= collectionView.contentOffset.x
        
        if pinnedCollectionView == nil {
            var shouldStartDragOutTimer = false
            if touchPoint.y < candidateCollectionView.frame.minY && !ignoreDragOutOnTop {
                shouldStartDragOutTimer = true
            } else if touchPoint.y > candidateCollectionView.frame.maxY && !ignoreDragOutOnBottom {
                shouldStartDragOutTimer = true
            }
            if shouldStartDragOutTimer {
                if folderRemovalTimer != nil {
                    return
                }
                folderRemovalTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(folderRemoveTimerHandler), userInfo: nil, repeats: false)
                return
            }
        }
        
        folderRemovalTimer?.invalidate()
        folderRemovalTimer = nil
        
        var destinationIndexPath: IndexPath
        let flowLayout = pageCell.collectionView.collectionViewLayout as! UICollectionViewFlowLayout
        var isEdgeCell = false
        let appsPerRow = pinnedCollectionView == nil ? appsRowsOnFolder : appsPerRow
        
        if let indexPath = pageCell.collectionView.indexPathForItem(at: touchPoint), pageCell == currentInteraction.currentPageCell {
            guard let itemCell = pageCell.collectionView.cellForItem(at: indexPath) as? BotItemCell else {
                return
            }
            let iconCenter = itemCell.imageView.center
            let offset = 20 as CGFloat
            let targetRect = CGRect(x: iconCenter.x - offset, y: iconCenter.y - offset, width: offset * 2, height: offset * 2)
            let convertedPoint = itemCell.convert(touchPoint, from: pageCell.collectionView)
            if targetRect.contains(convertedPoint) && indexPath.row != currentInteraction.currentIndexPath.row && collectionView == candidateCollectionView {
                if currentFolderInteraction != nil || currentInteraction.item is BotFolder || pinnedCollectionView == nil {
                    return
                }
                pageTimer?.invalidate()
                startFolderOperation(for: itemCell)
                return
            } else if convertedPoint.x < itemCell.imageView.frame.minX {
                destinationIndexPath = indexPath
            } else if convertedPoint.x > itemCell.imageView.frame.maxX {
                if (indexPath.row + 1) % appsPerRow == 0 {
                    destinationIndexPath = indexPath
                    isEdgeCell = true
                } else {
                    destinationIndexPath = IndexPath(item: indexPath.row + 1, section: 0)
                }
            } else {
                cancelFolderOperation()
                return
            }
        } else if touchPoint.x <= flowLayout.sectionInset.left { // move to previous page
            cancelFolderOperation()
            if collectionView == pinnedCollectionView {
                destinationIndexPath = IndexPath(item: 0, section: 0)
            } else if !(pageTimer?.isValid ?? false) && collectionView == candidateCollectionView {
                pageTimer = Timer.scheduledTimer(timeInterval: 0.7, target: self, selector: #selector(pageTimerHandler(_:)), userInfo: -1, repeats: false)
                return
            } else {
                return
            }
        } else if touchPoint.x > collectionView.frame.size.width - flowLayout.sectionInset.right { // move to next page
            if collectionView == pinnedCollectionView {
                if pinnedItems.count == 0 {
                    destinationIndexPath = IndexPath(item: 0, section: 0)
                } else {
                    destinationIndexPath = IndexPath(item: pinnedItems.count - 1, section: 0)
                }
            } else if !(pageTimer?.isValid ?? false) && collectionView == candidateCollectionView {
                pageTimer = Timer.scheduledTimer(timeInterval: 0.7, target: self, selector: #selector(pageTimerHandler(_:)), userInfo: 1, repeats: false)
                return
            } else {
                return
            }
        } else {
            //TODO: ‼️ fix this
            touchPoint.x += 15 // maximum spacing between cells
            if let indexPath = pageCell.collectionView.indexPathForItem(at: touchPoint) {
                destinationIndexPath = indexPath
            } else if let pinnedCollectionView = pinnedCollectionView, collectionView == candidateCollectionView && pinnedCollectionView.visibleCells.contains(currentInteraction.currentPageCell) {
                if items[currentPage].count < appsPerPage - 1 {
                    destinationIndexPath = IndexPath(item: items[currentPage].count + 1, section: 0)
                } else {
                    return
                }
            } else {
                cancelFolderOperation()
                pageTimer?.invalidate()
                return
            }
        }
        
        ignoreDragOutOnTop = false
        ignoreDragOutOnBottom = false
        cancelFolderOperation()
        pageTimer?.invalidate()
        pageTimer = nil
        folderTimer?.invalidate()
        folderTimer = nil
        isEdgeCell = destinationIndexPath.row % appsPerRow == 0
        
        let destinationLine = destinationIndexPath.row / appsPerRow
        let originalLine = currentInteraction.originalIndexPath.row / appsPerRow
        // dragging for same page same line
        if destinationLine == originalLine && currentInteraction.currentPageCell == currentInteraction.originalPageCell && !isEdgeCell {
            destinationIndexPath = IndexPath(item: destinationIndexPath.row - 1, section: 0)
        }
        
        if destinationIndexPath.row >= pageCell.collectionView.numberOfItems(inSection: 0) && destinationIndexPath.row > 0 {
            destinationIndexPath = IndexPath(item: destinationIndexPath.row - 1, section: 0)
        } else if destinationIndexPath.row == -1 {
            destinationIndexPath = IndexPath(item: 0, section: 0)
        }
        
        if destinationIndexPath.row != currentInteraction.currentIndexPath.row {
            if let pinnedCollectionView = pinnedCollectionView {
                if collectionView == pinnedCollectionView && !pinnedCollectionView.visibleCells.contains(currentInteraction.currentPageCell) {
                    moveToPinned(interaction: currentInteraction, pageCell: pageCell, destinationIndexPath: destinationIndexPath)
                    return
                } else if collectionView == candidateCollectionView && pinnedCollectionView.visibleCells.contains(currentInteraction.currentPageCell) {
                    moveFromPinned(interaction: currentInteraction, pageCell: pageCell, destinationIndexPath: destinationIndexPath)
                    return
                }
            }
            
            let numberOfItems = pageCell.collectionView.numberOfItems(inSection: 0)
            if currentInteraction.currentIndexPath.row < numberOfItems && destinationIndexPath.row < numberOfItems {
                pageCell.collectionView.moveItem(at: currentInteraction.currentIndexPath, to: destinationIndexPath)
                currentInteraction.currentIndexPath = destinationIndexPath
            }
        }
        
    }
    
    private func endDragInteraction(_ gestureRecognizer: UILongPressGestureRecognizer) {
        if currentFolderInteraction != nil {
            folderTimer?.invalidate()
            folderTimer = nil
            commitFolderOperation(didDrop: true)
            return
        }
        guard let currentInteraction = currentDragInteraction, let cell = currentInteraction.currentPageCell.collectionView.cellForItem(at: currentInteraction.currentIndexPath) as? BotItemCell else {
            return
        }
        updateState(forPageCell: currentInteraction.currentPageCell)
        let convertedRect = currentInteraction.currentPageCell.collectionView.convert(cell.frame, to: viewController.view)
        var visiblePageCells = [currentPageCell]
        if let pinnedCollectionView = pinnedCollectionView, let pageCell = pinnedCollectionView.visibleCells[0] as? BotPageCell {
            visiblePageCells.append(pageCell)
        }
        for cell in visiblePageCells.reduce([], { $0 + $1.collectionView.visibleCells }) {
            if let cell = cell as? BotItemCell {
                cell.label?.alpha = 1
                cell.startShaking()
            }
        }
        UIView.animate(withDuration: 0.25) {
            currentInteraction.liftView.transform = .identity
            currentInteraction.liftView.frame = convertedRect
        } completion: { _ in
            cell.contentView.isHidden = false
            currentInteraction.liftView.removeFromSuperview()
            self.currentDragInteraction = nil
        }
    }
    
    private func moveToPinned(interaction: HomeAppsDragInteraction, pageCell: BotPageCell, destinationIndexPath: IndexPath) {
        guard pinnedItems.count < appsPerRow else {
            return
        }
        guard interaction.item is Bot else {
            return
        }
        pinnedItems.insert(interaction.item, at: destinationIndexPath.row)
        var didRestoreSavedState = false
        if let savedState = interaction.savedState {
            items = savedState
            interaction.savedState = nil
            didRestoreSavedState = true
        } else {
            items[currentPage].remove(at: interaction.currentIndexPath.row)
        }
        // insert and update pinned collectionview
        pageCell.items = pinnedItems
        pageCell.draggedItem = interaction.item
        pageCell.collectionView.performBatchUpdates({
            pageCell.collectionView.insertItems(at: [destinationIndexPath])
        }, completion: nil)
        // delete and update candidate collectionview
        let currentPageCell = interaction.currentPageCell
        currentPageCell.items = items[currentPage]
        currentPageCell.collectionView.performBatchUpdates({
            currentPageCell.collectionView.deleteItems(at: [interaction.currentIndexPath])
            if didRestoreSavedState {
                let indexPath = IndexPath(item: appsPerPage - 1, section: 0)
                currentPageCell.collectionView.insertItems(at: [indexPath])
            }
        }, completion: nil)
        
        interaction.currentPageCell = pageCell
        interaction.currentIndexPath = destinationIndexPath
    }
    
    private func moveFromPinned(interaction: HomeAppsDragInteraction, pageCell: BotPageCell, destinationIndexPath: IndexPath) {
        var didMoveLastItem = false
        if items[currentPage].count == appsPerPage {
            didMoveLastItem = true
            interaction.savedState = items
            moveLastItem(inPage: currentPage)
            var indexPathsToReload: [IndexPath] = []
            for i in 0..<items.count {
                guard i != currentPage else { continue }
                let indexPath = IndexPath(item: i, section: 0)
                indexPathsToReload.append(indexPath)
            }
            candidateCollectionView.reloadItems(at: indexPathsToReload)
        }
        // update data
        items[currentPage].insert(interaction.item, at: destinationIndexPath.row)
        pinnedItems.remove(at: interaction.currentIndexPath.row)
        // update pinned collectionview
        interaction.currentPageCell.items = pinnedItems
        interaction.currentPageCell.draggedItem = interaction.item
        interaction.currentPageCell.collectionView.performBatchUpdates({
            interaction.currentPageCell.collectionView.deleteItems(at: [interaction.currentIndexPath])
        }, completion: nil)
        // update candidate collectionview
        pageCell.items = items[currentPage]
        pageCell.draggedItem = interaction.item
        pageCell.collectionView.performBatchUpdates({
            pageCell.collectionView.insertItems(at: [destinationIndexPath])
            if didMoveLastItem {
                pageCell.collectionView.deleteItems(at: [IndexPath(item: items[currentPage].count - 1, section: 0)])
            }
        }, completion: nil)
        
        interaction.currentPageCell = pageCell
        interaction.currentIndexPath = IndexPath(item: destinationIndexPath.row, section: 0)
    }
    
}

// MARK: - Page Timer Handler
extension HomeAppsManager {
    
    @objc func pageTimerHandler(_ timer: Timer) {
        guard let currentInteraction = currentDragInteraction, let offset = timer.userInfo as? Int else {
            return
        }
        pageTimer = nil
        guard let currentIndex = items[currentPage].firstIndex(where: { $0 === currentInteraction.item }) else {
            return
        }
        let currentPageInitialCount = items[currentPage].count
        let nextPage = currentPage + offset
        if nextPage < 0 || nextPage > items.count - 1 {
            return
        }
        if let savedState = currentInteraction.savedState {
            items = savedState
            currentInteraction.savedState = nil
        } else {
            items[currentPage].remove(at: currentIndex)
        }
        let appsPerPage = pinnedCollectionView == nil ? appsPerPageOnFolder : appsPerPage
        if items[nextPage].count == appsPerPage {
            currentInteraction.savedState = items
            moveLastItem(inPage: nextPage)
        }
        items[nextPage].append(currentInteraction.item)
        
        currentInteraction.currentPageCell.items = items[currentPage]
        currentInteraction.needsUpdate = true
        
        if currentInteraction.currentPageCell == currentInteraction.originalPageCell && items[currentPage].count < currentPageInitialCount {
            currentInteraction.currentPageCell.collectionView.performBatchUpdates({
                currentInteraction.currentPageCell.collectionView.deleteItems(at: [IndexPath(item: currentIndex, section: 0)])
            }, completion: nil)
        } else {
            currentInteraction.currentPageCell.collectionView.reloadData()
        }
        
        var newContentOffset = candidateCollectionView.contentOffset
        newContentOffset.x = candidateCollectionView.frame.width * CGFloat(currentPage + offset)
        candidateCollectionView.setContentOffset(newContentOffset, animated: true)
    }
    
}

