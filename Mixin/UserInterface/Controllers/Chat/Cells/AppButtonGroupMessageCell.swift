import UIKit

protocol AppButtonGroupMessageCellDelegate: class {
    func appButtonGroupMessageCell(_ cell: AppButtonGroupMessageCell, didSelectActionAt index: Int)
}

class AppButtonGroupMessageCell: DetailInfoMessageCell {
    
    weak var appButtonDelegate: AppButtonGroupMessageCellDelegate?
    
    private var buttonViews = [AppButtonView]()
    
    override var contentFrame: CGRect {
        return (viewModel as? AppButtonGroupViewModel)?.buttonGroupFrame ?? .zero
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? AppButtonGroupViewModel, let appButtons = viewModel.message.appButtons {
            buttonViews.forEach {
                $0.removeFromSuperview()
            }
            buttonViews = []
            for (i, frame) in viewModel.frames.enumerated() {
                let content = appButtons[i]
                let view = AppButtonView()
                view.frame = frame
                view.setTitle(content.label, colorHexString: content.color)
                view.button.tag = i
                view.button.addTarget(self, action: #selector(buttonAction(sender:)), for: .touchUpInside)
                buttonViews.append(view)
                messageContentView.addSubview(view)
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
