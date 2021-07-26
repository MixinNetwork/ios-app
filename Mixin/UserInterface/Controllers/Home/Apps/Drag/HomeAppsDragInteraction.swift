import UIKit

class HomeAppsDragInteraction {
    
    let placeholderView: HomeAppsSnapshotView
    let dragOffset: CGSize
    let item: HomeAppItem
    let originalPageCell: AppPageCell
    let originalIndexPath: IndexPath
    var currentPageCell: AppPageCell
    var currentIndexPath: IndexPath
    var needsUpdate = false
    var savedState: [[HomeAppItem]]?
    
    required init(placeholderView: HomeAppsSnapshotView, dragOffset: CGSize, item: HomeAppItem, originalPageCell: AppPageCell, originalIndexPath: IndexPath) {
        self.placeholderView = placeholderView
        self.dragOffset = dragOffset
        self.item = item
        self.originalPageCell = originalPageCell
        self.originalIndexPath = originalIndexPath
        currentPageCell = originalPageCell
        currentIndexPath = originalIndexPath
    }
    
    func movePlaceholderView(to point: CGPoint) {
        var offsettedTouchPoint = point
        offsettedTouchPoint.x += dragOffset.width
        offsettedTouchPoint.y += dragOffset.height
        placeholderView.center = offsettedTouchPoint
    }
    
    func copy() -> HomeAppsDragInteraction {
        let interaction = HomeAppsDragInteraction(placeholderView: placeholderView, dragOffset: dragOffset, item: item, originalPageCell: originalPageCell, originalIndexPath: originalIndexPath)
        interaction.currentPageCell = currentPageCell
        interaction.currentIndexPath = currentIndexPath
        return interaction
    }
    
}

struct HomeAppsDragInteractionTransfer {
    var gestureRecognizer: UILongPressGestureRecognizer
    var interaction: HomeAppsDragInteraction
}
