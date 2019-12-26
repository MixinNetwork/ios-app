import UIKit

protocol AppButtonGroupMessageCellDelegate: class {
    func appButtonGroupMessageCell(_ cell: AppButtonGroupMessageCell, didSelectActionAt index: Int)
}

class AppButtonGroupMessageCell: DetailInfoMessageCell {

    weak var appButtonDelegate: AppButtonGroupMessageCellDelegate?

    private var buttons = [UIButton]()
    
    override var contentFrame: CGRect {
        return (viewModel as? AppButtonGroupViewModel)?.buttonGroupFrame ?? .zero
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? AppButtonGroupViewModel, let appButtons = viewModel.message.appButtons {
            buttons.forEach {
                $0.removeFromSuperview()
            }
            buttons = []
            for (i, frame) in viewModel.frames.enumerated() {
                let buttonContent = appButtons[i]
                let button = UIButton(type: .system)
                button.frame = frame
                button.setTitle(buttonContent.label, for: .normal)
                button.setTitleColor(UIColor(hexString: buttonContent.color) ?? .gray, for: .normal)
                if let label = button.titleLabel {
                    label.numberOfLines = 0
                    label.font = MessageFontSet.appButtonTitle.scaled
                    label.adjustsFontForContentSizeCategory = true
                    label.lineBreakMode = .byCharWrapping
                }
                button.backgroundColor = .background
                button.layer.cornerRadius = 8
                button.clipsToBounds = true
                button.tag = i
                button.addTarget(self, action: #selector(buttonAction(sender:)), for: .touchUpInside)
                buttons.append(button)
                contentView.addSubview(button)
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
