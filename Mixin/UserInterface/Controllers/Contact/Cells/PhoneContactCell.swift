import UIKit
import MessageUI

class PhoneContactCell: UITableViewCell {

    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var indexTitleLabel: UILabel!
    @IBOutlet weak var phoneLabel: UILabel!
    
    static let cellIdentifier = "cell_identifier_phone_contact"
    static let cellHeight: CGFloat = 60

    var contact: PhoneContact?

    func render(contact: PhoneContact) {
        self.contact = contact
        nameLabel.text = contact.fullName
        indexTitleLabel.text = contact.fullName[0]
        phoneLabel.text = contact.phoneNumber
    }

    @IBAction func inviteAction(_ sender: Any) {
        if MFMessageComposeViewController.canSendText() {
            sendSMS()
        } else {
            let inviteController = UIActivityViewController(activityItems: [Localized.CONTACT_INVITE],
                                                            applicationActivities: nil)
            UIApplication.currentActivity()?.present(inviteController, animated: true, completion: nil)
        }
    }
    
}

extension PhoneContactCell: MFMessageComposeViewControllerDelegate {

    private func sendSMS() {
        guard let phoneContact = self.contact else {
            return
        }

        let controller = MFMessageComposeViewController()
        controller.body = Localized.CONTACT_INVITE
        controller.recipients = [phoneContact.phoneNumber]
        controller.messageComposeDelegate = self
        UIApplication.currentActivity()?.present(controller, animated: true, completion: nil)
    }

    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        controller.dismiss(animated: true, completion: nil)
    }
}


