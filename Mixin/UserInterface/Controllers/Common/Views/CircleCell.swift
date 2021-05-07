import UIKit

protocol CircleCellDelegate: AnyObject {
    func circleCellDidSelectEditingButton(_ cell: CircleCell)
}

class CircleCell: UITableViewCell {
    
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var circleImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var rightView: UIView!
    @IBOutlet weak var isCurrentImageView: UIImageView!
    @IBOutlet weak var unreadMessageCountLabel: RoundedInsetLabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    weak var delegate: CircleCellDelegate?
    
    var circleEditingStyle: CircleEditingButton.Style? {
        didSet {
            updateEditingButton(style: circleEditingStyle)
        }
    }
    
    var unreadCount = 0 {
        didSet {
            if unreadCount > 0 {
                unreadMessageCountLabel.isHidden = false
                unreadMessageCountLabel.text = "\(unreadCount)"
            } else {
                unreadMessageCountLabel.isHidden = true
            }
        }
    }
    
    var isCurrent = false {
        didSet {
            unreadMessageCountLabel.isHidden = isCurrent || unreadCount <= 0
            isCurrentImageView.isHidden = !isCurrent
        }
    }
    
    private lazy var editingButton: CircleEditingButton = {
        let button = CircleEditingButton()
        button.addTarget(self, action: #selector(circleEditAction), for: .touchUpInside)
        button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        button.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        editingButtonIfLoaded = button
        return button
    }()
    
    private weak var editingButtonIfLoaded: CircleEditingButton?
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if let superview = superview, !(superview is UITableView) {
            superview.backgroundColor = .background
        }
    }
    
    func setImagePatternColor(id: String?) {
        if let id = id {
            let index = id.positiveHashCode() % UIColor.circleColors.count
            circleImageView.tintColor = UIColor.circleColors[index]
        } else {
            circleImageView.tintColor = R.color.icon_fill()
        }
    }
    
    @objc private func circleEditAction() {
        delegate?.circleCellDidSelectEditingButton(self)
    }
    
    private func updateEditingButton(style: CircleEditingButton.Style?) {
        if let style = circleEditingStyle {
            editingButton.style = style
            if editingButton.superview == nil {
                stackView.insertArrangedSubview(editingButton, at: 0)
            }
        } else if let button = editingButtonIfLoaded {
            stackView.removeArrangedSubview(button)
        }
    }
    
}
