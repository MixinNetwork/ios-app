import UIKit

protocol AppButtonDelegate: AnyObject {
    
    func appButtonCell(_ cell: MessageCell, didSelectActionAt index: Int)
    
    func contextMenuConfigurationForAppButtonGroupMessageCell(_ cell: MessageCell) -> UIContextMenuConfiguration?
    func previewForHighlightingContextMenuOfAppButtonGroupMessageCell(_ cell: MessageCell, with configuration: UIContextMenuConfiguration) -> UITargetedPreview?
    func previewForDismissingContextMenuOfAppButtonGroupMessageCell(_ cell: MessageCell, with configuration: UIContextMenuConfiguration) -> UITargetedPreview?
    
}
