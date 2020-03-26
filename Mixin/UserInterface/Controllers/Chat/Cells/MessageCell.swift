import UIKit

class MessageCell: UITableViewCell {
    
    let messageContentView = UIView()
    let backgroundImageView = UIImageView()
    
    lazy var quotedMessageView: QuotedMessageView = {
        let view = QuotedMessageView()
        quotedMessageViewIfLoaded = view
        return view
    }()
    
    private(set) weak var quotedMessageViewIfLoaded: QuotedMessageView?
    
    var viewModel: MessageViewModel?
    
    var contentFrame: CGRect {
        return backgroundImageView.frame
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        prepare()
    }
    
    func render(viewModel: MessageViewModel) {
        self.viewModel = viewModel
        if let quotedMessageViewModel = viewModel.quotedMessageViewModel {
            if quotedMessageView.superview == nil {
                messageContentView.addSubview(quotedMessageView)
            }
            quotedMessageView.frame = viewModel.quotedMessageViewFrame
            quotedMessageView.render(viewModel: quotedMessageViewModel)
        } else {
            quotedMessageViewIfLoaded?.removeFromSuperview()
        }
    }
    
    func prepare() {
        messageContentView.frame = bounds
        messageContentView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        messageContentView.backgroundColor = .clear
        contentView.addSubview(messageContentView)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = .clear
        messageContentView.insertSubview(backgroundImageView, at: 0)
    }
    
}
