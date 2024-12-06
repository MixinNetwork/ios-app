import UIKit

final class NavigationTitleView: UIStackView {
    
    private weak var titleLabel: UILabel!
    private weak var subtitleLabel: UILabel!
    
    var subtitle: String? {
        get {
            subtitleLabel.text
        }
        set {
            subtitleLabel.text = newValue
            layoutLabels()
        }
    }
    
    init(title: String, subtitle: String? = nil) {
        super.init(frame: .zero)
        
        axis = .vertical
        distribution = .fill
        alignment = .center
        spacing = 2
        
        let titleLabel = {
            let label = UILabel()
            label.textColor = R.color.text()
            label.text = title
            return label
        }()
        addArrangedSubview(titleLabel)
        self.titleLabel = titleLabel
        
        let subtitleLabel = {
            let label = UILabel()
            label.font = .systemFont(ofSize: 12, weight: .regular)
            label.textColor = R.color.text_quaternary()
            label.text = subtitle
            return label
        }()
        addArrangedSubview(subtitleLabel)
        self.subtitleLabel = subtitleLabel
        
        layoutLabels()
    }
    
    required init(coder: NSCoder) {
        fatalError("Storyboard/Xib not supported")
    }
    
    private func layoutLabels() {
        if let subtitle, !subtitle.isEmpty {
            titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        } else {
            titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        }
    }
    
}
