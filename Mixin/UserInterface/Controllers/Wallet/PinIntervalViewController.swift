import UIKit

class PinIntervalViewController: UITableViewController {

    private let intervals: [Double] = [ 60 * 15, 60 * 30, 60 * 60, 60 * 60 * 2, 60 * 60 * 6, 60 * 60 * 12, 60 * 60 * 24 ]

    @IBOutlet weak var minutes15Label: UILabel!
    @IBOutlet weak var minutes30Label: UILabel!
    @IBOutlet weak var hours2Label: UILabel!
    @IBOutlet weak var hours6Label: UILabel!
    @IBOutlet weak var hours12Label: UILabel!
    @IBOutlet weak var hours24Label: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        minutes15Label.text = Localized.WALLET_PIN_PAY_INTERVAL_MINUTES(intervals[0])
        minutes30Label.text = Localized.WALLET_PIN_PAY_INTERVAL_MINUTES(intervals[1])
        hours2Label.text = Localized.WALLET_PIN_PAY_INTERVAL_HOURS(intervals[3])
        hours6Label.text = Localized.WALLET_PIN_PAY_INTERVAL_HOURS(intervals[4])
        hours12Label.text = Localized.WALLET_PIN_PAY_INTERVAL_HOURS(intervals[5])
        hours24Label.text = Localized.WALLET_PIN_PAY_INTERVAL_HOURS(intervals[6])
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        cell.accessoryType = intervals[indexPath.row] == WalletUserDefault.shared.pinInterval ? .checkmark : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return Localized.WALLET_PIN_PAY_INTERVAL_TIPS
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let interval = intervals[indexPath.row]
        PinTipsView.instance(tips: Localized.WALLET_PIN_PAY_INTERVAL_CONFIRM) { (pin) in
            WalletUserDefault.shared.pinInterval = interval
            }.presentPopupControllerAnimated { [weak self] in
                self?.navigationController?.popViewController(animated: true)
        }
    }

    class func instance() -> UIViewController {
        let vc = Storyboard.wallet.instantiateViewController(withIdentifier: "wallet_pin_interval") as! PinIntervalViewController
        return ContainerViewController.instance(viewController: vc, title: Localized.WALLET_PIN_PAY_INTERVAL)
    }

}
