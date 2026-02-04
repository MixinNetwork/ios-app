import UIKit

final class FeatureItemView: UIStackView {
    
    init(image: UIImage, title: String, description: String) {
        super.init(frame: .zero)
        
        axis = .horizontal
        distribution = .fill
        alignment = .top
        spacing = 16
        
        let imageView = UIImageView(image: image)
        addArrangedSubview(imageView)
        imageView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        let titleLabel = UILabel()
        titleLabel.numberOfLines = 0
        titleLabel.textColor = R.color.text()
        titleLabel.setFont(
            scaledFor: .systemFont(ofSize: 16, weight: .medium),
            adjustForContentSize: true
        )
        titleLabel.text = title
        
        let descriptionLabel = UILabel()
        descriptionLabel.numberOfLines = 0
        descriptionLabel.textColor = R.color.text_tertiary()
        descriptionLabel.setFont(
            scaledFor: .systemFont(ofSize: 14),
            adjustForContentSize: true
        )
        descriptionLabel.text = description
        
        let titleStackView = UIStackView(
            arrangedSubviews: [titleLabel, descriptionLabel]
        )
        titleStackView.axis = .vertical
        titleStackView.distribution = .fill
        titleStackView.alignment = .fill
        titleStackView.spacing = 8
        titleStackView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        addArrangedSubview(titleStackView)
    }
    
    required init(coder: NSCoder) {
        fatalError("Storyboard/Xib not supported")
    }
    
}
