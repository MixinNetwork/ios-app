import UIKit

protocol HomeAppsManagerDelegate: AnyObject {
        
}

class HomeAppsManager {
    
    weak var delegate: HomeAppsManagerDelegate?

    private unowned var viewController: UIViewController
    private unowned var candidateCollectionView: UICollectionView
    private unowned var pinnedCollectionView: UICollectionView
    
    private var longPressRecognizer: UILongPressGestureRecognizer
    private let feedback = UIImpactFeedbackGenerator()
    private var isEditing = false

    private var items: [HomeItemModel] = []
    private let appSize = CGSize(width: 60, height: 60)
    private var currentDragInteraction: AppDragInteraction?

    private var pageTimer: Timer?
    private var folderTimer: Timer?
    private var folderRemovalTimer: Timer?
    
    init(viewController: UIViewController, candidateCollectionView: UICollectionView, pinnedCollectionView: UICollectionView) {
        self.viewController = viewController
        self.candidateCollectionView = candidateCollectionView
        self.pinnedCollectionView = pinnedCollectionView
        
        //self.candidateCollectionView.dataSource = self
        //self.candidateCollectionView.delegate = self
        //self.pinnedCollectionView.dataSource = self
        //self.pinnedCollectionView.delegate = self
        
        longPressRecognizer = UILongPressGestureRecognizer()
        longPressRecognizer.addTarget(self, action: #selector(handleLongPressGesture(_:)))
        self.viewController.view.addGestureRecognizer(longPressRecognizer)
    }
    
}

extension HomeAppsManager {
    
    private func collectionView(at point: CGPoint) -> UICollectionView? {
        if pinnedCollectionView.frame.contains(viewController.view.convert(point, to: pinnedCollectionView)) {
            return pinnedCollectionView
        } else if candidateCollectionView.frame.contains(viewController.view.convert(point, to: candidateCollectionView)) {
            return candidateCollectionView
        } else {
            return nil
        }
    }
    
    func touchedViewInfos(at point: CGPoint) -> (collectionView: UICollectionView, cell: HomeAppCollectionCell, indexPath: IndexPath) {
        let collectionView: UICollectionView
        if pinnedCollectionView.frame.contains(viewController.view.convert(point, to: pinnedCollectionView)) {
            collectionView = pinnedCollectionView
        } else {
            collectionView = candidateCollectionView
        }
        let convertedPoint = viewController.view.convert(point, to: collectionView)
        if let indexPath = collectionView.indexPathForItem(at: convertedPoint), let cell = collectionView.cellForItem(at: indexPath) as? HomeAppCollectionCell {
            return (collectionView, cell, indexPath)
        } else {
            return (collectionView, collectionView.visibleCells[0] as! HomeAppCollectionCell, IndexPath(item: 0, section: 0))
        }
    }
    
    func enterEditingMode(suppressHaptic: Bool = false) {
        guard !isEditing else { return }
        if !suppressHaptic {
            feedback.impactOccurred()
        }
        for cell in candidateCollectionView.visibleCells + pinnedCollectionView.visibleCells {
            if let cell = cell as? HomeAppCollectionCell {
                cell.enterEditingMode()
            }
        }
        isEditing = true
    }
    
    func leaveEditingMode() {
        guard isEditing else { return }
        isEditing = false
        for cell in candidateCollectionView.visibleCells + pinnedCollectionView.visibleCells {
            if let cell = cell as? HomeAppCollectionCell {
                cell.leaveEditingMode()
            }
        }
    }
    
}

// MARK: - Handle drag & drop
extension HomeAppsManager {
    
    @objc private func handleLongPressGesture(_ gestureRecognizer: UILongPressGestureRecognizer) {
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
        guard let view = viewController.view.hitTest(touchPoint, with: nil), view.bounds.size.equalTo(appSize) else { return }
        guard let collectionView = collectionView(at: touchPoint) else { return }
        touchPoint = gestureRecognizer.location(in: collectionView)
        touchPoint.x -= collectionView.contentOffset.x
        
        if let indexPath = collectionView.indexPathForItem(at: touchPoint), let cell = collectionView.cellForItem(at: indexPath) as? HomeAppCollectionCell, let item = cell.model {
            let dragOffset = CGSize(width: cell.center.x - touchPoint.x, height: cell.center.y - touchPoint.y)
            var offsettedTouchPoint = gestureRecognizer.location(in: collectionView)
            offsettedTouchPoint.x += dragOffset.width
            offsettedTouchPoint.y += dragOffset.height
            
            let liftView = cell.snapshotView
            liftView.center = viewController.view.convert(offsettedTouchPoint, from: collectionView)
            viewController.view.addSubview(liftView)
            cell.contentView.isHidden = true
            enterEditingMode()
            currentDragInteraction = AppDragInteraction(liftView: liftView, dragOffset: dragOffset, item: item, originalCell: cell, originalIndexPath: indexPath)
            UIView.animate(withDuration: 0.25, animations: {
                liftView.transform = CGAffineTransform.identity.scaledBy(x: 1.3, y: 1.3)
                liftView.alpha = 0.8
            })
        }
    }
    
    private func updateDragInteraction(_ gestureRecognizer: UILongPressGestureRecognizer) {
        var touchPoint = gestureRecognizer.location(in: viewController.view)
        guard let currentInteraction = currentDragInteraction else { return }
        guard let collectionView = collectionView(at: touchPoint) else { return }
        touchPoint = gestureRecognizer.location(in: collectionView)
        let convertedTouchPoint = viewController.view.convert(touchPoint, from: collectionView)
        currentInteraction.moveLiftView(to: convertedTouchPoint)
        if currentInteraction.needsUpdate {
            return
        }
        touchPoint.x -= collectionView.contentOffset.x
        
        folderRemovalTimer?.invalidate()
        folderRemovalTimer = nil
        
        var destinationIndexPath: IndexPath
        let flowLayout = collectionView.collectionViewLayout as! UICollectionViewFlowLayout
        let appsPerRow = 4
        var isEdgeCell = false
        
        if let indexPath = collectionView.indexPathForItem(at: touchPoint), let cell = collectionView.cellForItem(at: indexPath) as? HomeAppCollectionCell, cell == currentInteraction.currentCell {
            let iconCenter = cell.contentView.center
            let offset = 20 as CGFloat
            let targetRect = CGRect(x: iconCenter.x - offset, y: iconCenter.y - offset, width: offset * 2, height: offset * 2)
            let convertedPoint = cell.convert(touchPoint, from: collectionView)
            
            if targetRect.contains(convertedPoint) && indexPath.row != currentInteraction.currentIndexPath.row && collectionView == candidateCollectionView {
                if currentDragInteraction != nil || currentInteraction.item is HomeFolderModel {
                    return
                }
                pageTimer?.invalidate()
                startFolderOperation(for: cell)
                return
            } else if convertedPoint.x < cell.contentView.frame.minX {
                destinationIndexPath = indexPath
            } else if convertedPoint.x > cell.contentView.frame.maxX {
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
            
        } else if touchPoint.x > collectionView.frame.size.width - flowLayout.sectionInset.right { // move to next page
            
        }
    }
    
    private func endDragInteraction(_ gestureRecognizer: UILongPressGestureRecognizer) {
        
    }
}

// MARK: - Handler folder operation
extension HomeAppsManager {
    
    private func startFolderOperation(for cell: HomeAppCollectionCell) {
    
    }
    
    private func cancelFolderOperation() {
        
    }
}
