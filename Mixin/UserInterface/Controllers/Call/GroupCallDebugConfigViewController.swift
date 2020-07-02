import UIKit

class GroupCallDebugConfigViewController: UITableViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.clearsSelectionOnViewWillAppear = false
        tableView.register(R.nib.settingCell)
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 6
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.setting, for: indexPath)!
        cell.updateAccessory(.switch(isOn: false, isEnabled: true), animated: false)
        cell.subtitleLabel.isHidden = true
        if !cell.accessorySwitch.allTargets.contains(self) {
            cell.accessorySwitch.addTarget(self, action: #selector(toggle(_:)), for: .valueChanged)
            cell.accessorySwitch.tag = indexPath.row
        }
        switch indexPath.row {
        case 0:
            cell.accessorySwitch.isOn = GroupCallDebugConfig.throwErrorOnOfferGeneration
            cell.titleLabel.text = "throwErrorOnOfferGeneration"
        case 1:
            cell.accessorySwitch.isOn = GroupCallDebugConfig.invalidResponseOnPublishing
            cell.titleLabel.text = "invalidResponseOnPublishing"
        case 2:
            cell.accessorySwitch.isOn = GroupCallDebugConfig.throwOnSettingSdpFromPublishingResponse
            cell.titleLabel.text = "throwErrorSettingSdpFromPublishingResponse"
        case 3:
            cell.accessorySwitch.isOn = GroupCallDebugConfig.invalidResponseOnSubscribing
            cell.titleLabel.text = "invalidResponseOnSubscribing"
        case 4:
            cell.accessorySwitch.isOn = GroupCallDebugConfig.throwErrorOnSettingSdpFromSubscribingResponse
            cell.titleLabel.text = "throwErrorOnSettingSdpFromSubscribingResponse"
        case 5:
            cell.accessorySwitch.isOn = GroupCallDebugConfig.throwErrorOnAnswerGeneration
            cell.titleLabel.text = "throwErrorOnAnswerGeneration"
        default:
            break
        }
        return cell
    }
    
    @objc private func toggle(_ sender: UISwitch) {
        switch sender.tag {
        case 0:
            GroupCallDebugConfig.throwErrorOnOfferGeneration = sender.isOn
        case 1:
            GroupCallDebugConfig.invalidResponseOnPublishing = sender.isOn
        case 2:
            GroupCallDebugConfig.throwOnSettingSdpFromPublishingResponse = sender.isOn
        case 3:
            GroupCallDebugConfig.invalidResponseOnSubscribing = sender.isOn
        case 4:
            GroupCallDebugConfig.throwErrorOnSettingSdpFromSubscribingResponse = sender.isOn
        case 5:
            GroupCallDebugConfig.throwErrorOnAnswerGeneration = sender.isOn
        default:
            break
        }
    }
    
}
