import UIKit

final class CollectiblesSortButton: UIButton {
    
    private var isShowingMenu = false
    
    override func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        willDisplayMenuFor configuration: UIContextMenuConfiguration,
        animator: UIContextMenuInteractionAnimating?
    ) {
        super.contextMenuInteraction(interaction, willDisplayMenuFor: configuration, animator: animator)
        isShowingMenu = true
        updateColors()
    }
    
    override func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        willEndFor configuration: UIContextMenuConfiguration,
        animator: UIContextMenuInteractionAnimating?
    ) {
        super.contextMenuInteraction(interaction, willEndFor: configuration, animator: animator)
        isShowingMenu = false
        updateColors()
    }
    
    func updateColors() {
        let backgroundColor: UIColor
        let titleColor: UIColor
        let borderColor: UIColor
        if isShowingMenu {
            backgroundColor = R.color.background_secondary()!
            titleColor = R.color.theme()!
            borderColor = R.color.theme()!
        } else {
            backgroundColor = R.color.background()!
            titleColor = R.color.text()!
            borderColor = R.color.collectible_outline()!
        }
        self.backgroundColor = backgroundColor
        setTitleColor(titleColor, for: .normal)
        layer.borderColor = borderColor.resolvedColor(with: traitCollection).cgColor
    }
    
}
