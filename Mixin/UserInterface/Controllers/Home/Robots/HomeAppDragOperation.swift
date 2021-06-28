import UIKit

class AppDragInteraction {

    let item: HomeItemModel
    
    let originalCell: HomeAppCollectionCell
    let originalIndexPath: IndexPath
    
    var currentCell: HomeAppCollectionCell
    var currentIndexPath: IndexPath
    
    let liftView: UIView
    let dragOffset: CGSize
    
    var needsUpdate = false
    var savedState: [HomeItemModel]?

    required init(liftView: UIView, dragOffset: CGSize, item: HomeItemModel, originalCell: HomeAppCollectionCell, originalIndexPath: IndexPath) {
        self.liftView = liftView
        self.dragOffset = dragOffset
        self.item = item
        self.originalCell = originalCell
        self.originalIndexPath = originalIndexPath
        currentCell = originalCell
        currentIndexPath = originalIndexPath
    }

    func moveLiftView(to point: CGPoint) {
        var offsettedTouchPoint = point
        offsettedTouchPoint.x += dragOffset.width
        offsettedTouchPoint.y += dragOffset.height
        liftView.center = offsettedTouchPoint
    }
}

struct AppDragInteractionTransfer {
    var gestureRecognizer: UILongPressGestureRecognizer
    var interaction: AppDragInteraction
}
