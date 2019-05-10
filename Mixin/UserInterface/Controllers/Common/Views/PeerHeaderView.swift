import UIKit

class PeerHeaderView: GeneralTableViewHeader {
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        labelTopConstraint.constant = 10
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        labelTopConstraint.constant = 10
    }
    
}
