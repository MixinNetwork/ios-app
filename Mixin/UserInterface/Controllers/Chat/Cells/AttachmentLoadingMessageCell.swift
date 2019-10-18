import UIKit

protocol AttachmentLoadingMessageCellDelegate: class {
    func attachmentLoadingCellDidSelectNetworkOperation(_ cell: UITableViewCell & AttachmentLoadingMessageCell)
}

protocol AttachmentLoadingMessageCell: class {
    var viewModel: MessageViewModel? { get }
    var operationButton: NetworkOperationButton! { get }
    var attachmentLoadingDelegate: AttachmentLoadingMessageCellDelegate? { get set }
    func updateProgress()
    func updateOperationButtonStyle()
}

extension AttachmentLoadingMessageCell {
    
    func updateProgress() {
        guard let viewModel = viewModel as? AttachmentLoadingViewModel else {
            return
        }
        operationButton.style = .busy(progress: viewModel.progress ?? 0)
    }
    
    func updateOperationButtonStyle() {
        guard let viewModel = viewModel as? AttachmentLoadingViewModel else {
            return
        }
        operationButton.style = viewModel.operationButtonStyle
    }
    
}
