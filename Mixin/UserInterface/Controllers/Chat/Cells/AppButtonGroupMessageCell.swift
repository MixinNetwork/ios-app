import UIKit

protocol AppButtonGroupMessageCellDelegate: AnyObject {
    
    func appButtonGroupMessageCell(_ cell: AppButtonGroupMessageCell, didSelectActionAt index: Int)
    
    @available(iOS 13.0, *)
    func contextMenuConfigurationForAppButtonGroupMessageCell(_ cell: AppButtonGroupMessageCell) -> UIContextMenuConfiguration?
    @available(iOS 13.0, *)
    func previewForHighlightingContextMenuOfAppButtonGroupMessageCell(_ cell: AppButtonGroupMessageCell, with configuration: UIContextMenuConfiguration) -> UITargetedPreview?
    @available(iOS 13.0, *)
    func previewForDismissingContextMenuOfAppButtonGroupMessageCell(_ cell: AppButtonGroupMessageCell, with configuration: UIContextMenuConfiguration) -> UITargetedPreview?
    
}

class AppButtonGroupMessageCell: DetailInfoMessageCell {
    
    weak var appButtonDelegate: AppButtonGroupMessageCellDelegate?
    
    private(set) var buttonViews = [AppButtonView]()
    
    override var contentFrame: CGRect {
        return (viewModel as? AppButtonGroupViewModel)?.buttonGroupFrame ?? .zero
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? AppButtonGroupViewModel, let appButtons = viewModel.message.appButtons {
            buttonViews.forEach {
                $0.removeFromSuperview()
            }
            buttonViews = []
            for (i, frame) in viewModel.frames.enumerated() {
                let content = appButtons[i]
                let view = AppButtonView()
                view.frame = frame
                view.setTitle(content.label, colorHexString: content.color)
                view.button.tag = i
                view.button.addTarget(self, action: #selector(buttonAction(sender:)), for: .touchUpInside)
                if #available(iOS 13.0, *) {
                    // According to disassembly result of UIKitCore from iOS 13.4.1
                    // UITableView's context menu handler cancels any context menu interaction
                    // on UIControl subclasses, therefore we have to handle it here
                    let interaction = UIContextMenuInteraction(delegate: self)
                    view.button.addInteraction(interaction)
                }
                buttonViews.append(view)
                messageContentView.addSubview(view)
            }
        }
    }
    
    override func prepare() {
        super.prepare()
        timeLabel.isHidden = true
        statusImageView.isHidden = true
    }
    
    @objc func buttonAction(sender: Any) {
        guard let sender = sender as? UIButton else {
            return
        }
        appButtonDelegate?.appButtonGroupMessageCell(self, didSelectActionAt: sender.tag)
    }
    
}

@available(iOS 13.0, *)
extension AppButtonGroupMessageCell: UIContextMenuInteractionDelegate {
    
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        appButtonDelegate?.contextMenuConfigurationForAppButtonGroupMessageCell(self)
    }
    
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, previewForHighlightingMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        appButtonDelegate?.previewForHighlightingContextMenuOfAppButtonGroupMessageCell(self, with: configuration)
    }
    
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, previewForDismissingMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        appButtonDelegate?.previewForDismissingContextMenuOfAppButtonGroupMessageCell(self, with: configuration)
    }
    
}
