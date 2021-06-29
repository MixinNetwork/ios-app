import UIKit

class HomeAppsDragInteraction {
    
    let item: BotItem
    
    let originalPageCell: BotPageCell
    let originalIndexPath: IndexPath
    
    var currentPageCell: BotPageCell
    var currentIndexPath: IndexPath
    
    let liftView: UIView
    let dragOffset: CGSize
    
    var needsUpdate = false
    var savedState: [[BotItem]]?
    
    required init(liftView: UIView, dragOffset: CGSize, item: BotItem, originalPageCell: BotPageCell, originalIndexPath: IndexPath) {
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
    
}

struct HomeAppsDragInteractionTransfer {
    var gestureRecognizer: UILongPressGestureRecognizer
    var interaction: HomeAppsDragInteraction
}
