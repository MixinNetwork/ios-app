import UIKit

class MessageCell: UITableViewCell {
    
    let backgroundImageView = UIImageView()
    
    lazy var quotedMessageView: QuotedMessageView = {
        let view = QuotedMessageView()
        quotedMessageViewIfLoaded = view
        return view
    }()
    
    private(set) weak var quotedMessageViewIfLoaded: QuotedMessageView?
    
    var viewModel: MessageViewModel?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        prepare()
    }
    
    var contentFrame: CGRect {
        return backgroundImageView.frame
    }
    
    func render(viewModel: MessageViewModel) {
        self.viewModel = viewModel
        if viewModel.quotedMessageViewModel == nil {
            quotedMessageViewIfLoaded?.removeFromSuperview()
        } else {
            if quotedMessageView.superview == nil {
                contentView.addSubview(quotedMessageView)
            }
            quotedMessageView.frame = viewModel.quotedMessageViewFrame
        }
    }
    
    func prepare() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = .clear
        contentView.insertSubview(backgroundImageView, at: 0)
    }
    
}
