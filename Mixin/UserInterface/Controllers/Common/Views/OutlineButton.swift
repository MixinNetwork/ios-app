import UIKit

final class OutlineButton: UIButton {
    
    @IBInspectable var normalBackgroundColor: UIColor = R.color.background()! {
        didSet {
            updateColors()
        }
    }
    
    @IBInspectable var normalOutlineColor: UIColor = R.color.collectible_outline()! {
        didSet {
            updateColors()
        }
    }
    
    override var isSelected: Bool {
        didSet {
            updateColors()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        initializeProperties()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initializeProperties()
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
    
    func updateColors() {
        let backgroundColor: UIColor
        let borderColor: UIColor
        if isSelected {
            backgroundColor = R.color.background_secondary()!
            borderColor = R.color.theme()!
        } else {
            backgroundColor = normalBackgroundColor
            borderColor = normalOutlineColor
        }
        self.backgroundColor = backgroundColor
        layer.borderColor = borderColor.resolvedColor(with: traitCollection).cgColor
    }
    
    private func initializeProperties() {
        setTitleColor(R.color.theme()!, for: .selected)
        setTitleColor(R.color.theme()!, for: [.highlighted, .selected])
        layer.borderWidth = 1
        updateColors()
    }
    
}
