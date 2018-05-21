import UIKit

protocol DataMessageCellDelegate: class {
    func dataMessageCellDidSelectNetworkOperation(_ cell: DataMessageCell)
}

class DataMessageCell: CardMessageCell {

    @IBOutlet weak var extensionNameWrapperView: UIView!
    @IBOutlet weak var extensionNameLabel: UILabel!
    @IBOutlet weak var operationButton: NetworkOperationButton!
    @IBOutlet weak var filenameLabel: UILabel!
    @IBOutlet weak var sizeLabel: UILabel!

    weak var cellDelegate: DataMessageCellDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        operationButton.bounds = operationButton.bounds
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        var mediaExpired = false
        if let viewModel = viewModel as? DataMessageViewModel {
            if let mediaStatus = viewModel.message.mediaStatus {
                let sentByMe = viewModel.message.userId == AccountAPI.shared.accountUserId
                switch mediaStatus {
                case MediaStatus.PENDING.rawValue:
                    operationButton.isHidden = false
                    if viewModel.progress == nil {
                        viewModel.progress = 0
                    }
                    operationButton.style = .busy(viewModel.progress ?? 0)
                    extensionNameWrapperView.isHidden = true
                case MediaStatus.DONE.rawValue:
                    operationButton.isHidden = true
                    operationButton.style = .finished
                    extensionNameWrapperView.isHidden = false
                case MediaStatus.CANCELED.rawValue:
                    operationButton.isHidden = false
                    operationButton.style = sentByMe ? .upload : .download
                    extensionNameWrapperView.isHidden = true
                case MediaStatus.EXPIRED.rawValue:
                    mediaExpired = true
                    operationButton.isHidden = false
                    operationButton.style = .expired
                    extensionNameWrapperView.isHidden = true
                default:
                    break
                }
            } else {
                operationButton.isHidden = true
                operationButton.style = .finished
                extensionNameWrapperView.isHidden = false
            }

            if let mediaMimeType = viewModel.message.mediaMimeType {
                extensionNameLabel.text = FileManager.default.pathExtension(mimeType: mediaMimeType)
            }
            filenameLabel.text = viewModel.message.name
            sizeLabel.text =  mediaExpired ? Localized.CHAT_FILE_EXPIRED : viewModel.sizeRepresentation
        }
    }
    
    @IBAction func operationAction(_ sender: Any) {
        cellDelegate?.dataMessageCellDidSelectNetworkOperation(self)
    }
    
}

extension DataMessageCell: ProgressInspectableMessageCell {
    
    func updateProgress(viewModel: ProgressInspectableMessageViewModel) {
        operationButton.style = .busy(viewModel.progress ?? 0)
        sizeLabel.text = viewModel.sizeRepresentation
    }
    
}
