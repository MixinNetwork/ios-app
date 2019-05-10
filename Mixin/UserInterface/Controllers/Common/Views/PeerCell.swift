import UIKit

class PeerCell: UITableViewCell {
    
    static let height: CGFloat = 70
    
    class var nib: UINib {
        return UINib(nibName: "PeerCell", bundle: .main)
    }
    
    class var reuseIdentifier: String {
        return "peer"
    }
    
    @IBOutlet weak var peerInfoView: PeerInfoView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectedBackgroundView = makeSelectedBackgroundView()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        peerInfoView.prepareForReuse()
    }
    
    func render(result: SearchResult) {
        peerInfoView.render(result: result)
    }
    
    func render(conversation: ConversationItem) {
        peerInfoView.render(conversation: conversation)
    }
    
    func render(user: UserItem) {
        peerInfoView.render(user: user)
    }
    
    func render(receiver: MessageReceiver) {
        peerInfoView.render(receiver: receiver)
    }
    
    func makeSelectedBackgroundView() -> UIView? {
        return UIView.createSelectedBackgroundView()
    }
    
}
