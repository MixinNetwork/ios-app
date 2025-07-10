import UIKit

final class ConfigurationBasedOutlineButton: UIButton {
    
    override func updateConfiguration() {
        guard var config = configuration else {
            return
        }
        config.background.strokeWidth = 1
        if isSelected {
            config.baseForegroundColor = R.color.theme()!
            config.background.backgroundColor = R.color.background_secondary()!
            config.background.strokeColor = R.color.theme()!
        } else {
            config.baseForegroundColor = R.color.text()
            config.background.backgroundColor = R.color.background()!
            config.background.strokeColor = R.color.outline_primary()!
        }
        configuration = config
    }
    
    override func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        willDisplayMenuFor configuration: UIContextMenuConfiguration,
        animator: UIContextMenuInteractionAnimating?
    ) {
        super.contextMenuInteraction(interaction, willDisplayMenuFor: configuration, animator: animator)
        isSelected = true
    }
    
    override func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        willEndFor configuration: UIContextMenuConfiguration,
        animator: UIContextMenuInteractionAnimating?
    ) {
        super.contextMenuInteraction(interaction, willEndFor: configuration, animator: animator)
        isSelected = false
    }
    
}
