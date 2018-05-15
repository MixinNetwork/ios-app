
protocol AttachmentLoadingMessageCellDelegate: class {
    func attachmentLoadingCellDidSelectNetworkOperation(_ cell: MessageCell & AttachmentLoadingMessageCell)
}

protocol AttachmentLoadingMessageCell: class {
    weak var attachmentLoadingDelegate: AttachmentLoadingMessageCellDelegate? { get set }
    var operationButton: NetworkOperationButton! { get }
    func updateProgress(viewModel: AttachmentLoadingViewModel)
}
