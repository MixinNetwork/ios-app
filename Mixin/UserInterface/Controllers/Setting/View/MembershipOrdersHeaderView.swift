import UIKit

final class MembershipOrdersHeaderView: GeneralTableViewHeader {
    
    override func prepare() {
        super.prepare()
        label.setFont(scaledFor: .systemFont(ofSize: 12), adjustForContentSize: true)
        label.textColor = R.color.text_quaternary()
        labelTopConstraint.constant = 20
        labelBottomConstraint.constant = 0
    }
    
}
