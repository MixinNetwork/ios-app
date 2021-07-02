import Foundation

extension HomeAppsManager {
    
    @discardableResult
    func showFolder(from cell: BotFolderCell, isNewFolder: Bool = false, startInRename: Bool = false) -> HomeAppsFolderViewController {
        openFolderInfo = HomeAppsOpenFolderInfo(cell: cell, isNewFolder: isNewFolder)
        cell.stopShaking()
        let convertedFrame = cell.convert(cell.contentView.frame, to: AppDelegate.current.mainWindow)
        let folderViewController = HomeAppsFolderViewController.instance()
        folderViewController.modalPresentationStyle = .overFullScreen
        folderViewController.isEditing = self.isEditing
        folderViewController.folder = cell.item as? BotFolder
        folderViewController.currentPage = cell.currentPage
        folderViewController.sourceFrame = CGRect(origin: convertedFrame.origin, size: HomeAppsMode.nestedFolderSize)
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
    
    func startFolderInteraction(for itemCell: BotItemCell) {
        guard let dragInteraction = currentDragInteraction else { return }
        folderTimer = Timer.scheduledTimer(timeInterval: 0.7, target: self, selector: #selector(folderTimerHandler), userInfo: nil, repeats: false)
        dragInteraction.transitionToFolderWrapperView()
        
        let folderWrapperView = UIView(frame: itemCell.imageContainerView.frame)
        folderWrapperView.layer.cornerRadius = 12
        folderWrapperView.backgroundColor = R.color.background_secondary()
        itemCell.contentView.insertSubview(folderWrapperView, belowSubview: itemCell.imageContainerView)
        
        cancelFolderInteraction()
        if let folder = itemCell.item as? BotFolder {
            currentFolderInteraction = HomeAppsFolderDropInteraction(dragInteraction: dragInteraction, folder: folder, wrapperView: folderWrapperView)
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
    
    func cancelFolderInteraction() {
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
    
    func commitFolderInteraction(didDrop: Bool = false) {
        guard let folderInteraction = currentFolderInteraction, !folderInteraction.isDismissing else {
            return
        }
        updateState(forPageCell: folderInteraction.dragInteraction.currentPageCell)
        if let creationInteraction = folderInteraction as? HomeAppsFolderCreationInteraction {
            commit(folderCreationInteraction: creationInteraction, didDrop: didDrop)
        } else if let dropInteraction = folderInteraction as? HomeAppsFolderDropInteraction {
            commit(folderDropInteraction: dropInteraction, didDrop: didDrop)
        }
    }
    
    // create new folder
    private func commit(folderCreationInteraction interaction: HomeAppsFolderCreationInteraction, didDrop: Bool) {
        guard let page = items.firstIndex(where: { $0.contains { $0 === interaction.destinationApp } }),
              let sourceIndex = items[page].firstIndex(where: { $0 === interaction.dragInteraction.item }),
              let destinationIndex = items[page].firstIndex(where: { $0 === interaction.destinationApp }),
              let sourceApp = interaction.dragInteraction.item as? Bot else {
            return
        }
        //TODO: ‼️ fix name and id
        let newFolder = BotFolder(id: "\(Date().timeIntervalSince1970 * 1000)", name: "Folder", pages: [[interaction.destinationApp, sourceApp]])
        newFolder.isNewFolder = true
        items[page][destinationIndex] = newFolder
        let folderIndexPath = IndexPath(item: destinationIndex, section: 0)
        interaction.dragInteraction.currentPageCell.items = items[page]
        if !didDrop {
            // still press when folder was created
            interaction.dragInteraction.currentPageCell.collectionView.reloadItems(at: [folderIndexPath])
            showFolderPostInteraction(interaction, page: page, sourceIndex: sourceIndex, destinationIndex: destinationIndex, folderIndexPath: folderIndexPath, isNewFolder: true)
            newFolder.isNewFolder = false
        } else {
            // end press whne folder was created
            UIView.animate(withDuration: 0.25) {
                interaction.dragInteraction.liftView.alpha = 1
            }
            let destinationCell = interaction.dragInteraction.currentPageCell.collectionView.cellForItem(at: IndexPath(item: destinationIndex, section: 0)) as! BotItemCell
            let iconSnapshot = destinationCell.imageContainerView.snapshotView(afterScreenUpdates: false)!
            iconSnapshot.frame = destinationCell.convert(destinationCell.imageContainerView.frame, to: interaction.dragInteraction.currentPageCell)
            interaction.dragInteraction.currentPageCell.contentView.addSubview(iconSnapshot)
            
            let convertedIconFrame = interaction.dragInteraction.liftView.convert(interaction.dragInteraction.liftView.iconView.frame, to: interaction.dragInteraction.liftView.superview!)
            interaction.dragInteraction.liftView.iconView.frame = convertedIconFrame
            interaction.dragInteraction.liftView.superview!.addSubview(interaction.dragInteraction.liftView.iconView)
            interaction.dragInteraction.liftView.removeFromSuperview()
            interaction.dragInteraction.currentPageCell.collectionView.performBatchUpdates {
                interaction.dragInteraction.currentPageCell.collectionView.reloadItems(at: [folderIndexPath])
            } completion: { _ in
                let folderCell = interaction.dragInteraction.currentPageCell.collectionView.cellForItem(at: folderIndexPath) as! BotFolderCell
                folderCell.move(view: iconSnapshot, toCellPositionAtIndex: 0)
                folderCell.move(view: interaction.dragInteraction.liftView.iconView, toCellPositionAtIndex: 1) {
                    iconSnapshot.removeFromSuperview()
                    interaction.dragInteraction.liftView.iconView.removeFromSuperview()
                    self.currentFolderInteraction = nil
                    self.currentDragInteraction = nil
                    self.showFolderPostInteraction(interaction, page: page, sourceIndex: sourceIndex, destinationIndex: destinationIndex, folderIndexPath: folderIndexPath, isNewFolder: true)
                    newFolder.isNewFolder = false
                }
            }
            
        }
    }
    
    // drop into created folder
    private func commit(folderDropInteraction interaction: HomeAppsFolderDropInteraction, didDrop: Bool) {
        guard let page = items.firstIndex(where: { $0.contains { $0 === interaction.folder } }),
              let sourceIndex = items[page].firstIndex(where: { $0 === interaction.dragInteraction.item }),
              let destinationIndex = items[page].firstIndex(where: { $0 === interaction.folder }),
              let sourceApp = interaction.dragInteraction.item as? Bot else {
            return
        }
        
        let folderIndexPath = IndexPath(item: destinationIndex, section: 0)
        let folderCell = interaction.dragInteraction.currentPageCell.collectionView.cellForItem(at: folderIndexPath) as! BotFolderCell
        let item = folderCell.item as! BotFolder
        item.pages[folderCell.currentPage].append(sourceApp)
        
        if !didDrop {
            showFolderPostInteraction(interaction, page: page, sourceIndex: sourceIndex, destinationIndex: destinationIndex, folderIndexPath: folderIndexPath)
            cancelFolderInteraction()
        } else {
            UIView.animate(withDuration: 0.25) {
                interaction.dragInteraction.liftView.alpha = 1
            }
            let convertedIconFrame = interaction.dragInteraction.liftView.convert(interaction.dragInteraction.liftView.iconView.frame, to: interaction.dragInteraction.liftView.superview!)
            interaction.dragInteraction.liftView.iconView.frame = convertedIconFrame
            interaction.dragInteraction.liftView.superview!.addSubview(interaction.dragInteraction.liftView.iconView)
            interaction.dragInteraction.liftView.removeFromSuperview()
            
            let folderCell = interaction.dragInteraction.currentPageCell.collectionView.cellForItem(at: folderIndexPath) as! BotFolderCell
            folderCell.move(view: interaction.dragInteraction.liftView.iconView, toCellPositionAtIndex: item.pages[folderCell.currentPage].count - 1) {
                var didRestoreSavedState = false
                if let savedState = interaction.dragInteraction.savedState {
                    self.items = savedState
                    interaction.dragInteraction.currentPageCell.items = self.items[page]
                    didRestoreSavedState = true
                } else if folderIndexPath.row < sourceIndex {
                    self.items[page].remove(at: sourceIndex)
                    interaction.dragInteraction.currentPageCell.items = self.items[page]
                }
                self.currentFolderInteraction = nil
                self.currentDragInteraction = nil
                interaction.dragInteraction.currentPageCell.collectionView.performBatchUpdates {
                    folderCell.item = item
                    interaction.dragInteraction.liftView.iconView.removeFromSuperview()
                    folderCell.moveToFirstAvailablePage()
                    if folderIndexPath.row < sourceIndex {
                        interaction.dragInteraction.currentPageCell.collectionView.deleteItems(at: [IndexPath(item: sourceIndex, section: 0)])
                        if didRestoreSavedState {
                            interaction.dragInteraction.currentPageCell.collectionView.insertItems(at: [IndexPath(item: self.mode.appsPerPage, section: 0)])
                        }
                    }
                } completion: { _ in
                    interaction.dragInteraction.liftView.iconView.removeFromSuperview()
                    if folderIndexPath.row > sourceIndex {
                        if didRestoreSavedState {
                            self.items[page].remove(at: sourceIndex)
                        }
                        interaction.dragInteraction.currentPageCell.items = self.items[page]
                        interaction.dragInteraction.currentPageCell.collectionView.performBatchUpdates({
                            interaction.dragInteraction.currentPageCell.collectionView.deleteItems(at: [IndexPath(item: sourceIndex, section: 0)])
                            if didRestoreSavedState {
                                interaction.dragInteraction.currentPageCell.collectionView.insertItems(at: [IndexPath(item: self.mode.appsPerPage - 1, section: 0)])
                            }
                        }, completion: nil)
                    }
                }
            }
            
            UIView.animate(withDuration: 0.35) {
                interaction.wrapperView.transform = .identity
                folderCell.label?.alpha = 1
            } completion: { _ in
                interaction.wrapperView.removeFromSuperview()
                folderCell.folderWrapperView.isHidden = false
                folderCell.startShaking()
            }
            
        }
    }
    
    func showFolderPostInteraction(_ interaction: HomeAppsFolderInteraction, page: Int, sourceIndex: Int, destinationIndex: Int, folderIndexPath: IndexPath, isNewFolder: Bool = false) {
        let folderIndexPath = IndexPath(item: destinationIndex, section: 0)
        interaction.dragInteraction.currentPageCell.items = items[page]
        let folderCell = interaction.dragInteraction.currentPageCell.collectionView.cellForItem(at: folderIndexPath) as! BotFolderCell
        let folderViewController = showFolder(from: folderCell, isNewFolder: isNewFolder)
        folderViewController.openAnimationDidEnd = { [unowned folderViewController] in
            self.items[page].remove(at: sourceIndex)
            interaction.dragInteraction.currentPageCell.collectionView.performBatchUpdates {
                interaction.dragInteraction.currentPageCell.collectionView.deleteItems(at: [IndexPath(item: sourceIndex, section: 0)])
            } completion: { _ in
                folderCell.stopShaking()
                let convertedFrame = folderCell.convert(folderCell.imageContainerView.frame, to: AppDelegate.current.mainWindow)
                folderViewController.sourceFrame = CGRect(origin: convertedFrame.origin, size: HomeAppsMode.nestedFolderSize)
                if !isNewFolder {
                    folderCell.folderWrapperView.isHidden = false
                }
                interaction.wrapperView.removeFromSuperview()
                self.currentFolderInteraction = nil
            }
        }
    }
    
    func updateFolderDragOutFlags() {
        guard let interaction = currentDragInteraction else { return }
        if interaction.liftView.center.y < candidateCollectionView.superview!.frame.minY {
            ignoreDragOutOnTop = true
        } else if interaction.liftView.center.y > candidateCollectionView.superview!.frame.maxY {
            ignoreDragOutOnBottom = true
        }
    }
    
}

extension HomeAppsManager {
    
    @objc func folderRemoveTimerHandler() {
        guard let dragInteraction = currentDragInteraction else { return }
        updateState(forPageCell: dragInteraction.currentPageCell)
        let pageCellIndexPath = candidateCollectionView.indexPath(for: dragInteraction.currentPageCell)!
        items[pageCellIndexPath.row].remove(at: dragInteraction.currentIndexPath.row)
        dragInteraction.currentPageCell.items = items[pageCellIndexPath.row]
        dragInteraction.currentPageCell.collectionView.deleteItems(at: [dragInteraction.currentIndexPath])
        let transfer = HomeAppsDragInteractionTransfer(gestureRecognizer: longPressRecognizer, interaction: dragInteraction)
        delegate?.didBeginFolderDragOut(transfer: transfer, on: self)
    }
    
    @objc func folderTimerHandler() {
        guard let folderInteraction = currentFolderInteraction, !folderInteraction.isDismissing else {
            return
        }
        folderTimer = nil
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.autoreverses = true
        animation.repeatCount = 2
        animation.toValue = 0.5
        animation.duration = 0.15
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            self.commitFolderInteraction()
        }
        folderInteraction.wrapperView.layer.add(animation, forKey: nil)
        CATransaction.commit()
    }
    
}

extension HomeAppsManager: HomeAppsFolderViewControllerDelegate {
    
    func openAnimationWillStart(on viewController: HomeAppsFolderViewController) {
        guard let info = openFolderInfo else { return }
        info.cell.imageContainerView?.isHidden = true
        info.cell.folderWrapperView.isHidden = true
    }
    
    func didChange(name: String, on viewController: HomeAppsFolderViewController) {
        guard let info = openFolderInfo else { return }
        info.cell.label?.text = name
    }
    
    func didSelect(app: Bot, on viewController: HomeAppsFolderViewController) {
        delegate?.didSelect(app: app, on: self)
    }
    
    func didEnterEditingMode(on viewController: HomeAppsFolderViewController) {
        enterEditingMode()
    }
    
    func didBeginFolderDragOut(withTransfer transfer: HomeAppsDragInteractionTransfer, on viewController: HomeAppsFolderViewController) {
        guard let info = openFolderInfo else { return }
        let folderIndex = items[currentPage].firstIndex(where: { $0 === info.folder })!
        let pageCell = currentPageCell
        if info.folder.pages.flatMap({ $0 }).count == 0 {
            items[currentPage].append(transfer.interaction.item)
            items[currentPage].remove(at: folderIndex)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: {
                self.perform(transfer: transfer)
                pageCell.draggedItem = transfer.interaction.item
                pageCell.items = self.items[self.currentPage]
                
                self.currentDragInteraction?.currentPageCell = pageCell
                self.currentDragInteraction?.currentIndexPath = IndexPath(item: pageCell.collectionView(pageCell.collectionView, numberOfItemsInSection: 0) - 1, section: 0)
                self.currentDragInteraction?.needsUpdate = false
                pageCell.collectionView.performBatchUpdates({
                    pageCell.collectionView.deleteItems(at: [IndexPath(item: folderIndex, section: 0)])
                    pageCell.collectionView.insertItems(at: [IndexPath(item: self.items[self.currentPage].count - 1, section: 0)])
                }, completion: { _ in
                    // force end the operation.
                    if self.longPressRecognizer.state == .possible {
                        self.endDragInteraction(self.longPressRecognizer)
                    }
                })
            })
        } else {
            perform(transfer: transfer)
            currentDragInteraction?.currentPageCell = pageCell
            if items[currentPage].count == mode.appsPerPage {
                currentDragInteraction?.savedState = items
                moveLastItem(inPage: currentPage)
            }
            items[currentPage].append(transfer.interaction.item)
            pageCell.draggedItem = transfer.interaction.item
            var indexPathRow = pageCell.collectionView(pageCell.collectionView, numberOfItemsInSection: 0)
            if indexPathRow == mode.appsPerPage {
                indexPathRow -= 1
            }
            let indexPath = IndexPath(item: indexPathRow, section: 0)
            currentDragInteraction?.currentIndexPath = indexPath
            currentDragInteraction?.needsUpdate = false
            pageCell.items = items[currentPage]
            pageCell.collectionView.performBatchUpdates({
                if self.currentDragInteraction?.savedState == nil {
                    pageCell.collectionView.insertItems(at: [indexPath])
                } else {
                    pageCell.collectionView.reloadItems(at: [indexPath])
                }
            }, completion: { _ in
                if self.longPressRecognizer.state == .possible {
                    self.endDragInteraction(self.longPressRecognizer)
                }
            })
        }
        if info.isNewFolder {
            info.shouldCancelCreation = true
        }
    }
    
    func dismissAnimationWillStart(currentPage: Int, updatedPages: [[Bot]], on viewController: HomeAppsFolderViewController) {
        guard let info = openFolderInfo else { return }
        info.folder.pages = updatedPages
        info.cell.item = info.folder
        info.cell.move(to: currentPage, animated: false)
        delegate?.didUpdateItems(on: self)
    }
    
    func dismissAnimationDidFinish(on viewController: HomeAppsFolderViewController) {
        guard let info = openFolderInfo else { return }
        viewController.dismiss(animated: false, completion: {
            self.openFolderInfo = nil
            info.cell.imageContainerView?.isHidden = false
            info.cell.folderWrapperView.isHidden = false
            if self.isEditing {
                info.cell.startShaking()
            }
        })
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
            if self.isEditing {
                info.cell.moveToFirstAvailablePage()
            } else {
                info.cell.move(to: 0, animated: true)
            }
        })
        guard let folderIndex = items[currentPage].firstIndex(where: { $0 === info.folder }) else { return }
        if info.shouldCancelCreation {
            let cell = currentPageCell.collectionView.cellForItem(at: IndexPath(item: folderIndex, section: 0)) as! BotFolderCell
            cell.revokeFolderCreation {
                self.items[self.currentPage][folderIndex] = info.folder.pages[0][0]
                self.currentPageCell.items = self.items[self.currentPage]
                self.currentPageCell.collectionView.performBatchUpdates({
                    self.currentPageCell.collectionView.reloadItems(at: [IndexPath(item: folderIndex, section: 0)])
                }, completion: nil)
            }
        } else if info.folder.pages.reduce(0, { $0 + $1.count }) == 0 {
            items[currentPage].remove(at: folderIndex)
            currentPageCell.delete(item: info.folder)
        }
    }
    
}
