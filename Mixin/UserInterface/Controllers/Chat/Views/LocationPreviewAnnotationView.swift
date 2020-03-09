import UIKit
import MapKit

class LocationPreviewAnnotationView: MKAnnotationView {
    
    let titleLabel = UILabel()
    let subtitleLabel = UILabel()
    
    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        prepare()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    private func prepare() {
        let image = R.image.conversation.ic_annotation_preview()!
        self.image = image
        bounds = CGRect(origin: .zero, size: image.size)
        titleLabel.setFont(scaledFor: .systemFont(ofSize: 16), adjustForContentSize: true)
        titleLabel.textColor = .text
        subtitleLabel.setFont(scaledFor: .systemFont(ofSize: 13), adjustForContentSize: true)
        subtitleLabel.textColor = .accessoryText
        let stackView = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.alignment = .leading
        stackView.distribution = .fill
        addSubview(stackView)
        stackView.snp.makeConstraints { (make) in
            make.centerY.equalToSuperview().offset(-8)
            make.leading.equalToSuperview().offset(52)
            make.trailing.equalToSuperview().offset(-12)
        }
    }
    
}
