import UIKit

class ClearStorageViewController: UITableViewController {

    @IBOutlet weak var photoCell: ClearStorageCell!
    @IBOutlet weak var videoCell: ClearStorageCell!
    @IBOutlet weak var audioCell: ClearStorageCell!
    @IBOutlet weak var fileCell: ClearStorageCell!
    
    @IBOutlet weak var photosLabel: UILabel!
    @IBOutlet weak var videosLabel: UILabel!
    @IBOutlet weak var audiosLabel: UILabel!
    @IBOutlet weak var filesLabel: UILabel!

    private var conversation: ConversationStorageUsage!
    private var isClearPhotos = true
    private var isClearVideos = true
    private var isClearAudios = true
    private var isClearFiles = true

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.tableFooterView = UIView()

        let conversationId = conversation.conversationId
        DispatchQueue.global().async { [weak self] in
            let categoryStorages = ConversationDAO.shared.getCategoryStorages(conversationId: conversationId)
            DispatchQueue.main.async {
                for categoryStorage in categoryStorages {
                    let mediaSize = categoryStorage.mediaSize
                    if categoryStorage.category.hasSuffix("_IMAGE") {
                        self?.photosLabel.text = VideoMessageViewModel.byteCountFormatter.string(fromByteCount: mediaSize)
                    } else if categoryStorage.category.hasSuffix("_VIDEO") {
                        self?.videosLabel.text = VideoMessageViewModel.byteCountFormatter.string(fromByteCount: mediaSize)
                    } else if categoryStorage.category.hasSuffix("_AUDIO") {
                        self?.audiosLabel.text = VideoMessageViewModel.byteCountFormatter.string(fromByteCount: mediaSize)
                    } else if categoryStorage.category.hasSuffix("_DATA") {
                        self?.filesLabel.text = VideoMessageViewModel.byteCountFormatter.string(fromByteCount: mediaSize)
                    }
                }

                self?.tableView.reloadData()
            }
        }
    }

    class func instance(conversation: ConversationStorageUsage) -> UIViewController {
        let vc = Storyboard.setting.instantiateViewController(withIdentifier: "clear_storage") as! ClearStorageViewController
        vc.conversation = conversation
        let container = ContainerViewController.instance(viewController: vc, title: conversation.getConversationName())
        container.automaticallyAdjustsScrollViewInsets = false
        return container
    }

}

extension ClearStorageViewController: ContainerViewControllerDelegate {

    func prepareBar(rightButton: StateResponsiveButton) {
        rightButton.isEnabled = true
        rightButton.setTitleColor(.systemTint, for: .normal)
    }

    func barRightButtonTappedAction() {
        
    }

    func textBarRightButton() -> String? {
        return Localized.ACTION_CLEAR
    }

}

extension ClearStorageViewController {

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.row {
        case 0:
            photoCell.accessoryType = isClearPhotos ? .checkmark : .none
            return photoCell
        case 1:
            videoCell.accessoryType = isClearVideos ? .checkmark : .none
            return videoCell
        case 2:
            audioCell.accessoryType = isClearAudios ? .checkmark : .none
            return audioCell
        case 3:
            fileCell.accessoryType = isClearFiles ? .checkmark : .none
            return fileCell
        default:
            return UITableViewCell()
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        switch indexPath.row {
        case 0:
            isClearPhotos = !isClearPhotos
        case 1:
            isClearVideos = !isClearVideos
        case 2:
            isClearAudios = !isClearAudios
        case 3:
            isClearFiles = !isClearFiles
        default:
            break
        }
        tableView.reloadRows(at: [indexPath], with: .none)
    }

}
