import UIKit

class GroupNotificationCell: UITableViewCell {

    @IBOutlet weak var muteLabel: UILabel!
    @IBOutlet weak var muteDetailLabel: UILabel!
    @IBOutlet weak var mutingIndicator: UIActivityIndicatorView!
    
    func render(conversation: ConversationItem) {
        guard let muteUntil = conversation.muteUntil else {
            return
        }
        if conversation.isMuted {
            muteLabel.text = Localized.PROFILE_STATUS_MUTED
            let date = DateFormatter.dateSimple.string(from: muteUntil.toUTCDate())
            muteDetailLabel.text = Localized.PROFILE_MUTE_DURATION_PREFIX + date
        } else {
            muteLabel.text = Localized.PROFILE_STATUS_NOT_MUTED
            muteDetailLabel.text = Localized.PROFILE_STATUS_NO
        }
    }
    
}
