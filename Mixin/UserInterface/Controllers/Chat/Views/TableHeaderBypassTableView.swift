import UIKit

final class TableHeaderBypassTableView: UITableView {
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitTest = super.hitTest(point, with: event)
        if let hitTest = hitTest, let tableHeaderView = tableHeaderView, hitTest.isDescendant(of: tableHeaderView) {
            return nil
        } else {
            return hitTest
        }
    }
    
}
