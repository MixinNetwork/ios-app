import UIKit

class LocationTableWrapperView: UIView {
    
    // If this view is on screen during userInterfaceStyle changing, e.g. light -> dark,
    // UIView.mask becomes a user-interaction blocking subview for some mysterious reason.
    // This is unrecoverable in whole app lifecycle.
    // Will be using hit test to bypass the mask view and return the tableView.
    private weak var tableView: UITableView?
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let superHitTest = super.hitTest(point, with: event)
        guard let mask = mask else {
            return superHitTest
        }
        if mask.frame.contains(point) {
            return tableView ?? superHitTest
        } else {
            return nil
        }
    }
    
    override func addSubview(_ view: UIView) {
        super.addSubview(view)
        if let view = view as? UITableView {
            self.tableView = view
        }
    }
    
}
