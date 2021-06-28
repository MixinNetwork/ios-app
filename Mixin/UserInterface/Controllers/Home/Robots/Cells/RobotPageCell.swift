import UIKit

enum RobotPageMode {
    case regular
    case folder
    case pinned
}

protocol RobotPageCellDelegate: AnyObject {

    func didSelect(cell: RobotItemCell, on pageCell: RobotPageCell)
    
}

class RobotPageCell: UICollectionViewCell {
    
    var mode: RobotPageMode = .regular {
        didSet {
            updateLayout()
        }
    }
    
}

extension RobotPageCell {
    
    private func updateLayout() {
        
    }
    
}
