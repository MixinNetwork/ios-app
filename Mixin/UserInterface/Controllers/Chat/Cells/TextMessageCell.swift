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
            contentLabel.lines = viewModel.lines
            contentLabel.lineOrigins = viewModel.lineOrigins
            contentLabel.highlightPaths = viewModel.highlightPaths
            contentLabel.links = viewModel.links
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
