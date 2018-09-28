import UIKit

protocol AttachmentLoadingMessageCellDelegate: class {
    func attachmentLoadingCellDidSelectNetworkOperation(_ cell: MessageCell & AttachmentLoadingMessageCell)
}

protocol AttachmentLoadingMessageCell: class {
    var operationButton: NetworkOperationButton! { get }
    var attachmentLoadingDelegate: AttachmentLoadingMessageCellDelegate? { get set }
    func updateProgress()
    func updateOperationButtonStyle()
}

extension AttachmentLoadingMessageCell where Self: MessageCell {
    
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
