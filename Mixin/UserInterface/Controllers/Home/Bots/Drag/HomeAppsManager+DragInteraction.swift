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
        print("update beginDrag")
        feedback.prepare()
        var touchPoint = gestureRecognizer.location(in: viewController.view)
        let (collectionView, pageCell) = viewInfos(at: touchPoint)
        touchPoint = gestureRecognizer.location(in: collectionView)
        touchPoint.x -= collectionView.contentOffset.x
        guard let indexPath = pageCell.collectionView.indexPathForItem(at: touchPoint),
              let cell = pageCell.collectionView.cellForItem(at: indexPath) as? AppCell,
              let item = cell.item else {
            // long press empty place to active editing mode
            enterEditingMode()
            return
        }
        let dragOffset = CGSize(width: cell.center.x - touchPoint.x, height: cell.center.y - touchPoint.y)
        var offsettedTouchPoint = gestureRecognizer.location(in: collectionView)
        offsettedTouchPoint.x += dragOffset.width
        offsettedTouchPoint.y += dragOffset.height
        // takes snapshot of touched cell and add to vc
        let placeholderView = cell.snapshotView
        placeholderView.center = viewController.view.convert(offsettedTouchPoint, from: collectionView)
        viewController.view.addSubview(placeholderView)
        cell.contentView.isHidden = true
        // start editing
        enterEditingMode()
        currentDragInteraction = HomeAppsDragInteraction(placeholderView: placeholderView, dragOffset: dragOffset, item: item, originalPageCell: pageCell, originalIndexPath: indexPath)
        UIView.animate(withDuration: 0.25, animations: {
            placeholderView.transform = CGAffineTransform.identity.scaledBy(x: 1.3, y: 1.3)
            placeholderView.alpha = 0.8
        })
    }
    
    private func updateDragInteraction(_ gestureRecognizer: UILongPressGestureRecognizer) {
        print("update drag --------------------------------- ")
        guard let currentInteraction = currentDragInteraction else { return }
        var touchPoint = gestureRecognizer.location(in: viewController.view)
        let (collectionView, pageCell) = viewInfos(at: touchPoint)
        touchPoint = gestureRecognizer.location(in: collectionView)
        // move snapshot of touched cell
        let convertedTouchPoint = viewController.view.convert(touchPoint, from: collectionView)
        currentInteraction.movePlaceholderView(to: convertedTouchPoint)
        guard !currentInteraction.needsUpdate else {
            print("update 1 needsUpdate")
            return
        }
        print("update 1 -- 1 in")
        touchPoint.x -= collectionView.contentOffset.x
        if isInAppsFolderViewController {
            var shouldStartDragOutTimer = false
            if touchPoint.y < candidateCollectionView.frame.minY && !ignoreDragOutOnTop {
                shouldStartDragOutTimer = true
            } else if touchPoint.y > candidateCollectionView.frame.maxY && !ignoreDragOutOnBottom {
                shouldStartDragOutTimer = true
            }
            if shouldStartDragOutTimer {
                if folderRemovalTimer != nil {
                    print("update 1  -- 2")
                    return
                }
                folderRemovalTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(folderRemoveTimerHandler), userInfo: nil, repeats: false)
                print("update 1  -- 3")
                return
            }
        }
        folderRemovalTimer?.invalidate()
        folderRemovalTimer = nil
        var destinationIndexPath: IndexPath
        var isEdgeCell = false
        let flowLayout = pageCell.collectionView.collectionViewLayout as! UICollectionViewFlowLayout
        let appsPerRow = isInAppsFolderViewController ? HomeAppsMode.folder.appsPerRow : HomeAppsMode.regular.appsPerRow
        if let indexPath = pageCell.collectionView.indexPathForItem(at: touchPoint), pageCell == currentInteraction.currentPageCell { // move to valid indexPath
            print("update 2 move to valid indexPath, touched point: \(touchPoint) index: \(indexPath.item)")
            guard let itemCell = pageCell.collectionView.cellForItem(at: indexPath) as? AppCell else {
                print("update 2 -- 1 not app cell: \(indexPath.item)")
                return
            }
            let imageCenter = itemCell.imageContainerView.center
            let offset = 20 as CGFloat
            let targetRect = CGRect(x: imageCenter.x - offset, y: imageCenter.y - offset, width: offset * 2, height: offset * 2)
            let convertedPoint = itemCell.convert(touchPoint, from: pageCell.collectionView)
            let validOverlap = targetRect.contains(convertedPoint)
            print("update targetRect\(targetRect) convertedPoint\(convertedPoint) validOverlap:\(validOverlap)")
            if validOverlap && indexPath.row != currentInteraction.currentIndexPath.row && collectionView == candidateCollectionView { // move to create folder
                print("update 3 move to create folder")
                if currentFolderInteraction != nil || currentInteraction.item is AppFolderModel || isInAppsFolderViewController {
                    print("update 3 -- 1 return")
                    return
                }
                pageTimer?.invalidate()
                startFolderInteraction(for: itemCell)
                print("update 3 -- 2 start folder")
                return
            } else if convertedPoint.x < itemCell.imageContainerView.frame.minX { // move to previous of item
                destinationIndexPath = indexPath
                print("update 3 -- 3 move to previous of item \(convertedPoint.x) <> \(itemCell.imageContainerView.frame.minX) : \(indexPath.item)")
            } else if convertedPoint.x > itemCell.imageContainerView.frame.maxX { // move to next of item
                if (indexPath.row + 1) % appsPerRow == 0 {
                    destinationIndexPath = indexPath
                    isEdgeCell = true
                } else {
                    destinationIndexPath = IndexPath(item: indexPath.row + 1, section: 0)
                }
                print("update 3 -- 4 move to next of item \(convertedPoint.x) <> \(itemCell.imageContainerView.frame.minX) : \(destinationIndexPath.item)")
            } else {
                cancelFolderInteraction()
                print("update 3 -- 5 cancel folder: \(indexPath.item)")
                return
            }
        } else if touchPoint.x <= flowLayout.sectionInset.left { // move to previous page
            print("update 4 move to previous page")
            cancelFolderInteraction()
            if collectionView == pinnedCollectionView {
                destinationIndexPath = IndexPath(item: 0, section: 0)
                print("update 4 -- 1 : \(destinationIndexPath.item)")
            } else if !(pageTimer?.isValid ?? false) && collectionView == candidateCollectionView {
                pageTimer = Timer.scheduledTimer(timeInterval: 0.7, target: self, selector: #selector(pageTimerHandler(_:)), userInfo: -1, repeats: false)
                print("update 4 -- 2 start pagetimer")
                return
            } else {
                print("update 4 -- 3 return")
                return
            }
        } else if touchPoint.x > collectionView.frame.size.width - flowLayout.sectionInset.right { // move to next page
            print("update 5 move to next page")
            cancelFolderInteraction()
            if collectionView == pinnedCollectionView {
                print("update 5 -- 1 in pinned collection")
                if pinnedItems.count == 0 {
                    destinationIndexPath = IndexPath(item: 0, section: 0)
                } else {
                    destinationIndexPath = IndexPath(item: pinnedItems.count - 1, section: 0)
                }
            } else if !(pageTimer?.isValid ?? false) && collectionView == candidateCollectionView {
                pageTimer = Timer.scheduledTimer(timeInterval: 0.7, target: self, selector: #selector(pageTimerHandler(_:)), userInfo: 1, repeats: false)
                print("update 5 -- 2 start pagetimer in candicate")
                return
            } else {
                print("update 5 -- 3 return")
                return
            }
        } else {
            touchPoint.x += 22
            if let indexPath = pageCell.collectionView.indexPathForItem(at: touchPoint) {
                destinationIndexPath = indexPath
                print("update 6 -- 3 ")
            } else if let pinnedCollectionView = pinnedCollectionView, collectionView == candidateCollectionView && pinnedCollectionView.visibleCells.contains(currentInteraction.currentPageCell) { // move from pinned
                print("update 6 -- 4 ")
                if items[currentPage].count < HomeAppsMode.regular.appsPerPage - 1 {
                    destinationIndexPath = IndexPath(item: items[currentPage].count + 1, section: 0)
                    print("update 6 -- 5 :\(destinationIndexPath.item) ")
                } else {
                    print("update 6 -- 6 return")
                    return
                }
            } else {
                print("update 7 -- no condition hit")
                if collectionView == pinnedCollectionView {
                    print("update 7 -- 1 is pinned")
                    if pageCell.collectionView.numberOfItems(inSection: 0) == 0 {
                        destinationIndexPath = IndexPath(item: 0, section: 0)
                        print("update 7 -- 2 move 0")
                    } else {
                        destinationIndexPath = IndexPath(item: pageCell.collectionView.visibleCells.count, section: 0)
                        print("update 7 -- 3 move to last, count: \(pageCell.collectionView.numberOfItems(inSection: 0) + 1), visible:\(pageCell.collectionView.visibleCells.count)")
                    }
                } else if collectionView == candidateCollectionView {
                    destinationIndexPath = IndexPath(item: pageCell.collectionView.visibleCells.count, section: 0)
                } else {
                    print("update 7 -- 2 cancelfolder return")
                    cancelFolderInteraction()
                    pageTimer?.invalidate()
                    return
                }
            }
        }
        ignoreDragOutOnTop = false
        ignoreDragOutOnBottom = false
        cancelFolderInteraction()
        pageTimer?.invalidate()
        pageTimer = nil
        folderTimer?.invalidate()
        folderTimer = nil
        isEdgeCell = destinationIndexPath.row % appsPerRow == 0
        let destinationLine = destinationIndexPath.row / appsPerRow
        let originalLine = currentInteraction.originalIndexPath.row / appsPerRow
        print("update 19 - 1 isEdge: \(isEdgeCell) = \(destinationIndexPath.row) % \(appsPerRow), DLine\(destinationLine) RLine\(originalLine)")
        // dragging for same page same line
        if destinationLine == originalLine && currentInteraction.currentPageCell == currentInteraction.originalPageCell && !isEdgeCell {
            destinationIndexPath = IndexPath(item: destinationIndexPath.row - 1, section: 0)
            print("update 20 dragging for same page same line")
        }
        // make sure index is in range
        if destinationIndexPath.row >= pageCell.collectionView.numberOfItems(inSection: 0) && destinationIndexPath.row > 0 {
            destinationIndexPath = IndexPath(item: destinationIndexPath.row - 1, section: 0)
            print("update 21 🍎 destinationIndexPath.row\(destinationIndexPath.row),numberOfItems: \(pageCell.collectionView.numberOfItems(inSection: 0)), itemC: \(pinnedItems.count)")
        } else if destinationIndexPath.row == -1 {
            destinationIndexPath = IndexPath(item: 0, section: 0)
            print("update 22 🍒")
        }
        // final movement
        if destinationIndexPath.row != currentInteraction.currentIndexPath.row {
            if let pinnedCollectionView = pinnedCollectionView {
                print("update pin ... ")
                if collectionView == pinnedCollectionView && !pinnedCollectionView.visibleCells.contains(currentInteraction.currentPageCell) { // pin
                    moveToPinned(interaction: currentInteraction, pageCell: pageCell, destinationIndexPath: destinationIndexPath)
                    print("update pinned")
                    return
                } else if collectionView == candidateCollectionView && pinnedCollectionView.visibleCells.contains(currentInteraction.currentPageCell) { // unpin
                    moveFromPinned(interaction: currentInteraction, pageCell: pageCell, destinationIndexPath: destinationIndexPath)
                    print("update unpinned")
                    return
                }
            }
            print("update normal in ...")
            // normal move
            let numberOfItems = pageCell.collectionView.numberOfItems(inSection: 0)
            if currentInteraction.currentIndexPath.row < numberOfItems && destinationIndexPath.row < numberOfItems {
                print("update normal move: \(destinationIndexPath.item)")
                pageCell.collectionView.moveItem(at: currentInteraction.currentIndexPath, to: destinationIndexPath)
                currentInteraction.currentIndexPath = destinationIndexPath
            }
        }
        
    }
    
    func endDragInteraction(_ gestureRecognizer: UILongPressGestureRecognizer) {
        // create folder by dropped the item
        if currentFolderInteraction != nil {
            folderTimer?.invalidate()
            folderTimer = nil
            commitFolderInteraction(didDrop: true)
            return
        }
        guard let currentInteraction = currentDragInteraction, let cell = currentInteraction.currentPageCell.collectionView.cellForItem(at: currentInteraction.currentIndexPath) as? AppCell else {
            return
        }
        updateState(forPageCell: currentInteraction.currentPageCell)
        let convertedRect = currentInteraction.currentPageCell.collectionView.convert(cell.frame, to: viewController.view)
        var visiblePageCells = [currentPageCell]
        if let pinnedCollectionView = pinnedCollectionView, let pageCell = pinnedCollectionView.visibleCells[0] as? AppPageCell {
            visiblePageCells.append(pageCell)
        }
        for cell in visiblePageCells.reduce([], { $0 + $1.collectionView.visibleCells }) {
            if let cell = cell as? AppCell {
                cell.label?.alpha = 1
                cell.startShaking()
            }
        }
        UIView.animate(withDuration: 0.25) {
            currentInteraction.placeholderView.transform = .identity
            currentInteraction.placeholderView.frame = convertedRect
        } completion: { _ in
            cell.contentView.isHidden = false
            currentInteraction.placeholderView.removeFromSuperview()
            self.currentDragInteraction = nil
        }
    }
    
    private func moveToPinned(interaction: HomeAppsDragInteraction, pageCell: AppPageCell, destinationIndexPath: IndexPath) {
        guard pinnedItems.count < HomeAppsMode.pinned.appsPerPage else {
            return
        }
        guard interaction.item is AppModel else {
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
        // insert item and update pinned collectionview
        pageCell.items = pinnedItems
        pageCell.draggedItem = interaction.item
        pageCell.collectionView.performBatchUpdates({
            pageCell.collectionView.insertItems(at: [destinationIndexPath])
        }, completion: nil)
        // delete item and update candidate collectionview
        let currentPageCell = interaction.currentPageCell
        currentPageCell.items = items[currentPage]
        currentPageCell.collectionView.performBatchUpdates({
            currentPageCell.collectionView.deleteItems(at: [interaction.currentIndexPath])
            if didRestoreSavedState {
                let indexPath = IndexPath(item: HomeAppsMode.regular.appsPerPage - 1, section: 0)
                currentPageCell.collectionView.insertItems(at: [indexPath])
            }
        }, completion: nil)
        interaction.currentPageCell = pageCell
        interaction.currentIndexPath = destinationIndexPath
    }
    
    private func moveFromPinned(interaction: HomeAppsDragInteraction, pageCell: AppPageCell, destinationIndexPath: IndexPath) {
        var didMoveLastItem = false
        // need to move last item to next page
        if items[currentPage].count == HomeAppsMode.regular.appsPerPage {
            didMoveLastItem = true
            interaction.savedState = items
            moveLastItem(inPage: currentPage)
            var indexPathsToReload: [IndexPath] = []
            for page in 0..<items.count {
                guard page != currentPage else { continue }
                let indexPath = IndexPath(item: page, section: 0)
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
        let currentPageItemsInitialCount = items[currentPage].count
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
        let appsPerPage = isInAppsFolderViewController ? HomeAppsMode.folder.appsPerPage : HomeAppsMode.regular.appsPerPage
        if items[nextPage].count == appsPerPage {
            currentInteraction.savedState = items
            moveLastItem(inPage: nextPage)
        }
        items[nextPage].append(currentInteraction.item)
        currentInteraction.currentPageCell.items = items[currentPage]
        currentInteraction.needsUpdate = true
        if currentInteraction.currentPageCell == currentInteraction.originalPageCell && items[currentPage].count < currentPageItemsInitialCount {
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

