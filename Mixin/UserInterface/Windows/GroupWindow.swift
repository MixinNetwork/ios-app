import UIKit

class GroupWindow: BottomSheetView {

    @IBOutlet weak var containerView: UIView!

    private let groupView = GroupView.instance()

    override func awakeFromNib() {
        super.awakeFromNib()
        containerView.addSubview(groupView)
        groupView.snp.makeConstraints({ (make) in
            make.edges.equalToSuperview()
        })
    }

    override func dismissPopupControllerAnimated() {
        dismissView()
    }

    func updateGroup(conversation: ConversationItem, initialAnnouncementMode: CollapsingLabel.Mode = .collapsed) -> GroupWindow {
        groupView.render(conversation: conversation, superView: self, initialAnnouncementMode: initialAnnouncementMode)
        return self
    }

    class func instance() -> GroupWindow {
        return Bundle.main.loadNibNamed("GroupWindow", owner: nil, options: nil)?.first as! GroupWindow
    }
}
