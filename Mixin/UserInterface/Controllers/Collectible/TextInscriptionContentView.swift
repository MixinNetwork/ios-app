import UIKit
import Alamofire

final class TextInscriptionContentView: UIView {
    
    let label = UILabel()
    
    private let iconDimension: CGFloat
    private let spacing: CGFloat
    private let imageView = UIImageView()
    
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
    
    func reloadData(with url: URL) {
        textContentRequest?.cancel()
        label.text = nil
        textContentRequest = InscriptionContentSession
            .request(url)
            .responseString() { [weak label] response in
                switch response.result {
                case let .success(content):
                    label?.text = content
                case .failure:
                    break
                }
            }
    }
    
    private func loadSubviews() {
        addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            make.width.height.equalTo(iconDimension)
        }
        imageView.contentMode = .scaleAspectFit
        imageView.image = R.image.collectible_text()
        
        label.textAlignment = .center
        label.textColor = UIColor(displayP3RgbValue: 0xFFA724)
        addSubview(label)
        label.snp.makeConstraints { make in
            make.top.equalTo(imageView.snp.bottom).offset(spacing)
            make.leading.trailing.bottom.equalToSuperview()
        }
    }
    
}
