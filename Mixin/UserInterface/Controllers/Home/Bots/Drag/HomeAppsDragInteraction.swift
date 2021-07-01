import UIKit

class HomeAppsDragInteraction {
    
    let item: BotItem
    
    let originalPageCell: BotPageCell
    let originalIndexPath: IndexPath
    
    var currentPageCell: BotPageCell
    var currentIndexPath: IndexPath
    
    let liftView: HomeAppSnapshotView
    let dragOffset: CGSize
    
    var needsUpdate = false
    var savedState: [[BotItem]]?
    
    required init(liftView: HomeAppSnapshotView, dragOffset: CGSize, item: BotItem, originalPageCell: BotPageCell, originalIndexPath: IndexPath) {
        self.liftView = liftView
        self.dragOffset = dragOffset
        self.item = item
        self.originalPageCell = originalPageCell
        self.originalIndexPath = originalIndexPath
        currentPageCell = originalPageCell
        currentIndexPath = originalIndexPath
    }
    
    func moveLiftView(to point: CGPoint) {
        var offsettedTouchPoint = point
        offsettedTouchPoint.x += dragOffset.width
        offsettedTouchPoint.y += dragOffset.height
        liftView.center = offsettedTouchPoint
    }
    
    func copy() -> HomeAppsDragInteraction {
        let interaction = HomeAppsDragInteraction(liftView: liftView, dragOffset: dragOffset, item: item, originalPageCell: originalPageCell, originalIndexPath: originalIndexPath)
        interaction.currentPageCell = currentPageCell
        interaction.currentIndexPath = currentIndexPath
        return interaction
    }
    
    func transitionToFolderWrapperView() {
        UIView.animate(withDuration: 0.2) {
            self.liftView.nameView.alpha = 0
        }
    }
    
    func transitionFromFolderWrapperView() {
        UIView.animate(withDuration: 0.2) {
            self.liftView.nameView.alpha = 1
        }
    }
}

struct HomeAppsDragInteractionTransfer {
    var gestureRecognizer: UILongPressGestureRecognizer
    var interaction: HomeAppsDragInteraction
}
