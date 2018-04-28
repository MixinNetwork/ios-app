import UIKit
import MessageUI

class PhoneContactViewController: UITableViewController {

    @IBOutlet weak var fullnameLabel: UILabel!
    @IBOutlet weak var phoneNumberLabel: UILabel!
    @IBOutlet weak var nameIndexLabel: UILabel!
    
    private var phoneContact: PhoneContact!

    override func viewDidLoad() {
        super.viewDidLoad()

        fullnameLabel.text = phoneContact.fullName
        phoneNumberLabel.text = phoneContact.phoneNumber
        nameIndexLabel.text = phoneContact.fullName[0]
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard indexPath.section == 1 else {
            return
        }

        if MFMessageComposeViewController.canSendText() {
            sendSMS()
        } else {
            let inviteController = UIActivityViewController(activityItems: [Localized.CONTACT_INVITE],
                                                            applicationActivities: nil)
            present(inviteController, animated: true, completion: nil)
        }
    }

    class func instance(phoneContact: PhoneContact) -> UIViewController {
        let vc = Storyboard.contact.instantiateViewController(withIdentifier: "phone_contact") as! PhoneContactViewController
        vc.phoneContact = phoneContact
        return ContainerViewController.instance(viewController: vc, title: Localized.PROFILE_TITLE)
    }

}

extension PhoneContactViewController: MFMessageComposeViewControllerDelegate {

    private func sendSMS() {
        let controller = MFMessageComposeViewController()
        controller.body = Localized.CONTACT_INVITE
        controller.recipients = [phoneContact.phoneNumber]
        controller.messageComposeDelegate = self
        self.present(controller, animated: true, completion: nil)
    }

    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        controller.dismiss(animated: true, completion: nil)
    }
}
