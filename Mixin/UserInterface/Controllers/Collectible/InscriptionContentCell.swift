import UIKit

final class InscriptionContentCell: UITableViewCell {
    
    @IBOutlet weak var contentImageView: UIImageView!
    @IBOutlet weak var placeholderImageView: UIImageView!
    
    private weak var textContentView: TextInscriptionContentView?
    
    override func prepareForReuse() {
        super.prepareForReuse()
        if let textContentView {
            textContentView.prepareForReuse()
            textContentView.isHidden = true
        }
        contentImageView.sd_cancelCurrentImageLoad()
    }
    
    func setTextContent(collectionIconURL: URL, textContentURL: URL) {
        let textContentView: TextInscriptionContentView
        if let view = self.textContentView {
            view.isHidden = false
            textContentView = view
        } else {
            textContentView = TextInscriptionContentView(iconDimension: 100, spacing: 10)
            textContentView.label.numberOfLines = 10
            textContentView.label.font = .systemFont(ofSize: 24, weight: .semibold)
            textContentView.label.adjustsFontSizeToFitWidth = true
            textContentView.label.minimumScaleFactor = 12 / 24
            self.textContentView = textContentView
            contentView.addSubview(textContentView)
            textContentView.snp.makeConstraints { make in
                make.top.greaterThanOrEqualTo(contentImageView).offset(40)
                make.leading.equalTo(contentImageView).offset(15)
                make.trailing.equalTo(contentImageView).offset(-15)
                make.bottom.lessThanOrEqualTo(contentImageView).offset(-40)
                make.centerY.equalTo(contentImageView)
            }
        }
        textContentView.reloadData(collectionIconURL: collectionIconURL,
                                   textContentURL: textContentURL)
    }
    
}
