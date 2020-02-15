import UIKit

class CardMessageTitleView: UIStackView {
    
    let titleLabel = UILabel()
    let subtitleLabel = UILabel()
    
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
        [titleLabel, subtitleLabel].forEach(addArrangedSubview(_:))
    }
    
}

extension CardMessageCell where RightView: CardMessageTitleView {
    
    var titleLabel: UILabel {
        rightView.titleLabel
    }
    
    var subtitleLabel: UILabel {
        rightView.subtitleLabel
    }
    
}
