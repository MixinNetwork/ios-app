import UIKit

class TextMessageCell: DetailInfoMessageCell {
    
    let contentLabel = TextMessageLabel()

    override func prepareForReuse() {
        backgroundImageView.image = nil
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? TextMessageViewModel {
            contentLabel.frame = viewModel.contentLabelFrame
            contentLabel.content = viewModel.content
            contentLabel.highlightPaths = viewModel.highlightPaths
            contentLabel.setNeedsDisplay()
        }
    }
    
    override func prepare() {
        super.prepare()
        contentView.addSubview(contentLabel)
        contentLabel.backgroundColor = .clear
        timeLabel.textColor = .infoGray
    }
    
}
