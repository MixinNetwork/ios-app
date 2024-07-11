import UIKit

final class AppButtonGroupMessageCell: DetailInfoMessageCell {
    
    let buttonsView = AppButtonGroupView()
    
    weak var appButtonDelegate: AppButtonDelegate?
    
    override var contentFrame: CGRect {
        (viewModel as? AppButtonGroupMessageViewModel)?.contentFrame ?? .zero
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? AppButtonGroupMessageViewModel, let appButtons = viewModel.message.appButtons {
            buttonsView.frame = viewModel.contentFrame
            buttonsView.layoutButtons(viewModel: viewModel.buttonsViewModel)
            for (i, content) in appButtons.enumerated() {
                let buttonView = buttonsView.buttonViews[i]
                let button = buttonView.button
                buttonView.setTitle(content.label, colorHexString: content.color)
                button.tag = i
                button.removeTarget(self, action: nil, for: .touchUpInside)
                button.addTarget(self, action: #selector(performButtonAction(_:)), for: .touchUpInside)
                
                // According to disassembly result of UIKitCore from iOS 13.4.1
                // UITableView's context menu handler cancels any context menu interaction
                // on UIControl subclasses, therefore we have to handle it here
                let interaction = UIContextMenuInteraction(delegate: self)
                button.addInteraction(interaction)
            }
        }
    }
    
    override func prepare() {
        super.prepare()
        timeLabel.isHidden = true
        statusImageView.isHidden = true
        messageContentView.addSubview(buttonsView)
    }
    
    @objc private func performButtonAction(_ sender: UIButton) {
        appButtonDelegate?.appButtonCell(self, didSelectActionAt: sender.tag)
    }
    
}

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
