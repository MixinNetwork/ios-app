import UIKit
import MessageUI

class PhoneContactWindow: BottomSheetView {

    @IBOutlet weak var fullnameLabel: UILabel!
    @IBOutlet weak var phoneNumberLabel: UILabel!
    @IBOutlet weak var nameIndexLabel: UILabel!

    private var phoneContact: PhoneContact!

    func updatePhoneContact(phoneContact: PhoneContact) -> PhoneContactWindow {
        self.phoneContact = phoneContact
        fullnameLabel.text = phoneContact.fullName
        phoneNumberLabel.text = phoneContact.phoneNumber
        nameIndexLabel.text = phoneContact.fullName[0]
        return self
    }

    @IBAction func inviteAction(_ sender: Any) {
        dismissPopupControllerAnimated()
        if MFMessageComposeViewController.canSendText() {
            sendSMS()
        } else {
            let inviteController = UIActivityViewController(activityItems: [Localized.CONTACT_INVITE],
                                                            applicationActivities: nil)
            UIApplication.currentActivity()?.present(inviteController, animated: true, completion: nil)
        }
    }

    @IBAction func dismissAction(_ sender: Any) {
        dismissPopupControllerAnimated()
    }

    class func instance() -> PhoneContactWindow {
        return Bundle.main.loadNibNamed("PhoneContactWindow", owner: nil, options: nil)?.first as! PhoneContactWindow
    }
}

extension PhoneContactWindow: MFMessageComposeViewControllerDelegate {

    private func sendSMS() {
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
