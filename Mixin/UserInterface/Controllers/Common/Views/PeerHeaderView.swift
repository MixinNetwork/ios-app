import UIKit

final class PeerHeaderView: GeneralTableViewHeader {
    
    override func prepare() {
        super.prepare()
        labelTopConstraint.constant = 10
    }
    
}
