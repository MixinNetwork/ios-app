import UIKit

class ContactMessageCellRightView: UIStackView {
    
    let fullnameStackView = UIStackView()
    let fullnameLabel = UILabel()
    let badgeImageView = UIImageView()
    let idLabel = UILabel()
    
    init() {
        super.init(frame: .zero)
        prepare()
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func prepare() {
        axis = .vertical
        distribution = .fill
        alignment = .leading
        spacing = 4
        
        fullnameStackView.axis = .horizontal
        fullnameStackView.distribution = .fill
        fullnameStackView.alignment = .center
        fullnameStackView.spacing = ContactMessageViewModel.titleSpacing
        
        fullnameLabel.font = ContactMessageViewModel.fullnameFontSet.scaled
        fullnameLabel.textColor = .text
        fullnameLabel.adjustsFontForContentSizeCategory = true
        fullnameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        fullnameLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        badgeImageView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        badgeImageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        badgeImageView.contentMode = .left
        [fullnameLabel, badgeImageView].forEach(fullnameStackView.addArrangedSubview(_:))
        
        idLabel.font = ContactMessageViewModel.idFontSet.scaled
        idLabel.textColor = .accessoryText
        idLabel.adjustsFontForContentSizeCategory = true
        [fullnameStackView, idLabel].forEach(addArrangedSubview(_:))
    }
    
}
