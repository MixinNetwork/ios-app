import UIKit
import MixinServices

final class ConversationDateHeaderView: UITableViewHeaderFooterView {
    
    static let height: CGFloat = 44
    
    let backgroundImageView = UIImageView(image: R.image.time_bubble())
    let label = UILabel()
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        backgroundConfiguration = .clear()
        tintColor = .clear
        
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(backgroundImageView)
        
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.textColor = UIColor(displayP3Red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
        label.adjustsFontForContentSizeCategory = true
        contentView.addSubview(label)
        
        NSLayoutConstraint.activate([
            backgroundImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            backgroundImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: backgroundImageView.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: backgroundImageView.trailingAnchor, constant: -10),
            label.topAnchor.constraint(equalTo: backgroundImageView.topAnchor),
            label.bottomAnchor.constraint(equalTo: backgroundImageView.bottomAnchor, constant: -2),
            label.heightAnchor.constraint(equalToConstant: 24),
            label.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),
        ])
        updateFontSize()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Xib not supported")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        alpha = 1
        updateFontSize()
    }
    
    override func addInteraction(_ interaction: any UIInteraction) {
        // Prevent UITableView from adding _UIScrollPocketContainerInteraction,
        // which extends the scroll view's topEdgeEffect into floating headers on iOS 27.
    }
    
    private func updateFontSize() {
        label.font = MessageFontSet.systemMessage.scaled
    }
    
}
