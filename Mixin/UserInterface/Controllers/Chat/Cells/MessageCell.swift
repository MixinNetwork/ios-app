import UIKit

class MessageCell: UITableViewCell {

    let backgroundImageView = UIImageView()

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        prepare()
    }
    
    var contentFrame: CGRect {
        return backgroundImageView.frame
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        if animated {
            UIView.beginAnimations(nil, context: nil)
            UIView.setAnimationDuration(0.15)
        }
        backgroundImageView.alpha = selected ? 0.65 : 1
        if animated {
            UIView.commitAnimations()
        }
    }

    func render(viewModel: MessageViewModel) {
        
    }
    
    func prepare() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = .clear
        contentView.insertSubview(backgroundImageView, at: 0)
    }

}
