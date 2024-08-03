import UIKit

final class NavigationTitleView: UIStackView {
    
    let titleLabel = UILabel()
    let subtitleLabel = UILabel()
    
    init() {
        super.init(frame: .zero)
        prepare()
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        prepare()
    }
    
    private func prepare() {
        axis = .vertical
        distribution = .fill
        alignment = .center
        spacing = 2
        titleLabel.font = .scaledFont(ofSize: 16, weight: .medium)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = R.color.text()
        subtitleLabel.font = .preferredFont(forTextStyle: .caption1)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textColor = R.color.text_quaternary()
        addArrangedSubview(titleLabel)
        addArrangedSubview(subtitleLabel)
    }
    
}
