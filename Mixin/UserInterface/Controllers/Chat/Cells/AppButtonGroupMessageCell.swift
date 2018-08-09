import UIKit

protocol AppButtonGroupMessageCellDelegate: class {
    func appButtonGroupMessageCell(_ cell: AppButtonGroupMessageCell, didSelectActionAt index: Int)
}

class AppButtonGroupMessageCell: DetailInfoMessageCell {

    weak var appButtonDelegate: AppButtonGroupMessageCellDelegate?

    private var buttonViews = [UIView]()
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? AppButtonGroupViewModel, let appButtons = viewModel.message.appButtons {
            buttonViews.forEach {
                $0.removeFromSuperview()
            }
            buttonViews = []
            for (i, frame) in viewModel.frames.enumerated() {
                let buttonContent = appButtons[i]
                let button = UIButton(frame: frame.button)
                contentView.addSubview(button)
                button.setBackgroundImage(#imageLiteral(resourceName: "ic_app_button_normal"), for: .normal)
                button.setBackgroundImage(#imageLiteral(resourceName: "ic_app_button_selected"), for: .highlighted)
                button.tag = i
                button.addTarget(self, action: #selector(buttonAction(sender:)), for: .touchUpInside)
                buttonViews.append(button)
                let label = UILabel(frame: frame.label)
                contentView.addSubview(label)
                label.numberOfLines = 0
                label.text = buttonContent.label
                label.font = AppButtonGroupViewModel.titleFont
                label.textColor = UIColor(hexString: buttonContent.color) ?? .gray
                label.textAlignment = .left
                label.lineBreakMode = .byCharWrapping
                buttonViews.append(label)
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
