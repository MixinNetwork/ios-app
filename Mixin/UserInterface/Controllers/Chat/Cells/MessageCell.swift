import UIKit

class MessageCell: UITableViewCell {

    let backgroundImageView = UIImageView()

    internal(set) var viewModel: MessageViewModel?
    
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
    }
    
    func prepare() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = .clear
        contentView.insertSubview(backgroundImageView, at: 0)
    }

}
