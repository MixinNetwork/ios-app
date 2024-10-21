import UIKit
import Alamofire

final class TextInscriptionContentView: UIView {
    
    let label = UILabel()
    
    private let iconDimension: CGFloat
    private let spacing: CGFloat
    private let imageView = UIImageView()
    private let imageMaskView = UIImageView(image: R.image.collection_token_mask())
    
    private var lastTextContentURL: URL?
    
    private weak var textContentRequest: Request?
    
    init(iconDimension: CGFloat, spacing: CGFloat) {
        self.iconDimension = iconDimension
        self.spacing = spacing
        super.init(frame: .zero)
        loadSubviews()
    }
    
    required init?(coder: NSCoder) {
        self.iconDimension = 50
        self.spacing = 4
        super.init(coder: coder)
        loadSubviews()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        imageMaskView.frame = imageView.bounds
    }
    
    func prepareForReuse() {
        imageView.sd_cancelCurrentImageLoad()
        textContentRequest?.cancel()
    }
    
    func reloadData(collectionIconURL: URL, textContentURL: URL) {
        imageView.sd_setImage(with: collectionIconURL)
        if textContentURL != lastTextContentURL {
            label.text = nil
            textContentRequest = InscriptionContentSession
                .request(textContentURL)
                .responseString(encoding: .utf8) { [weak self] response in
                    switch response.result {
                    case let .success(content):
                        guard let self else {
                            return
                        }
                        self.lastTextContentURL = textContentURL
                        self.label.text = content
                    case .failure:
                        break
                    }
                }
        }
    }
    
    private func loadSubviews() {
        isUserInteractionEnabled = false
        
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            make.width.height.equalTo(iconDimension)
        }
        imageView.contentMode = .scaleAspectFit
        
        imageMaskView.contentMode = .scaleAspectFit
        imageMaskView.frame = imageView.bounds
        imageView.mask = imageMaskView
        
        label.textAlignment = .center
        label.textColor = UIColor(displayP3RgbValue: 0xFFA724)
        addSubview(label)
        label.snp.makeConstraints { make in
            make.top.equalTo(imageView.snp.bottom).offset(spacing)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
    
}
