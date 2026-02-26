import UIKit

final class PriceDataUnavailableView: UIView {
    
    override class var layerClass: AnyClass {
        CAGradientLayer.self
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadSubview()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadSubview()
    }
    
    private func loadSubview() {
        let layer = self.layer as! CAGradientLayer
        layer.colors = [
            UIColor(displayP3RgbValue: 0xd9d9d9, alpha: 0.2).cgColor,
            UIColor(displayP3RgbValue: 0xd9d9d9, alpha: 0).cgColor,
        ]
        
        let label = UILabel()
        label.textColor = R.color.text_quaternary()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .caption1)
        label.adjustsFontForContentSizeCategory = true
        label.text = R.string.localizable.price_data_unavailable().uppercased()
        addSubview(label)
        label.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
        }
    }
    
}
