import UIKit

final class OutlineSegmentedControl: UIControl {
    
    var items: [UIImage] = [] {
        didSet {
            let updateContentSize = items.count != oldValue.count
            reloadData(items: items, updateContentSize: updateContentSize)
        }
    }
    
    private(set) var selectedItemIndex: Int?
    
    private let stackView = UIStackView()
    private let horizontalMargin: CGFloat = 4
    private let buttonWidth: CGFloat = 44
    
    private var buttons: [UIButton] = []
    private var separators: [UIView] = []
    private var contentSize = CGSize(width: 0, height: 38)
    
    override var intrinsicContentSize: CGSize {
        contentSize
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadSubviews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadSubviews()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateBorderColor()
        }
    }
    
    // Will not trigger the action of `valueChanged`
    func selectItem(at index: Int) {
        if let index = selectedItemIndex {
            buttons[index].tintColor = R.color.icon_tint()
        }
        buttons[index].tintColor = R.color.theme()
        selectedItemIndex = index
    }
    
    @objc private func tapItem(_ sender: UIButton) {
        guard selectedItemIndex != sender.tag else {
            return
        }
        selectItem(at: sender.tag)
        sendActions(for: .valueChanged)
    }
    
    private func reloadData(items: [UIImage], updateContentSize: Bool) {
        for button in buttons {
            button.removeFromSuperview()
        }
        for separator in separators {
            separator.removeFromSuperview()
        }
        for (index, item) in items.enumerated() {
            let button = UIButton(type: .system)
            button.setImage(item, for: .normal)
            button.tag = index
            button.tintColor = R.color.icon_tint()
            button.addTarget(self, action: #selector(tapItem(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(button)
            button.snp.makeConstraints { make in
                make.width.equalTo(buttonWidth)
            }
            buttons.append(button)
            if index != 0 {
                let separator = UIView()
                separator.backgroundColor = R.color.collectible_outline()
                separator.isUserInteractionEnabled = false
                addSubview(separator)
                separator.snp.makeConstraints { make in
                    make.width.equalTo(1)
                    make.height.equalTo(18)
                    make.centerY.equalToSuperview()
                    make.centerX.equalTo(snp.leading)
                        .offset(horizontalMargin + CGFloat(index) * buttonWidth)
                }
                separators.append(separator)
            }
        }
        if updateContentSize {
            contentSize.width = CGFloat(items.count) * buttonWidth + horizontalMargin * 2
            invalidateIntrinsicContentSize()
        }
    }
    
    private func updateBorderColor() {
        layer.borderColor = R.color.collectible_outline()!
            .resolvedColor(with: traitCollection)
            .cgColor
    }
    
    private func loadSubviews() {
        layer.borderWidth = 1
        layer.masksToBounds = true
        updateBorderColor()
        
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.top.bottom.centerX.equalToSuperview()
        }
    }
    
}
