import UIKit

class SegmentedControl: UIControl {
    
    var itemTitles = [String]() {
        didSet {
            reloadData()
        }
    }
    
    private(set) var selectedSegmentIndex = -1
    
    private lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.frame = bounds
        stackView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(stackView)
        return stackView
    }()
    
    private var buttons = [UIButton]()
    
    private func reloadData() {
        buttons = itemTitles.enumerated().map { (index, title) in
            let button = UIButton()
            button.titleLabel?.font = .systemFont(ofSize: 14)
            button.setTitle(title, for: .normal)
            button.setTitleColor(UIColor(displayP3RgbValue: 0xB8BDC7), for: .normal)
            button.setTitleColor(.highlightedText, for: .selected)
            button.tag = index
            button.addTarget(self, action: #selector(tapAction(_:)), for: .touchUpInside)
            stackView.insertArrangedSubview(button, at: index)
            return button
        }
        if let firstButton = buttons.first {
            firstButton.isSelected = true
            selectedSegmentIndex = 0
        }
    }
    
    @objc private func tapAction(_ sender: UIButton) {
        for button in buttons {
            let wasSelected = button.isSelected
            UIView.transition(with: button,
                              duration: 0.2,
                              options: .transitionCrossDissolve,
                              animations: { button.isSelected = button == sender },
                              completion: nil)
            if button == sender && button.isSelected != wasSelected {
                selectedSegmentIndex = button.tag
                sendActions(for: .valueChanged)
            }
        }
    }
    
}
