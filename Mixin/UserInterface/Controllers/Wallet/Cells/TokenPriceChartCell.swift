import UIKit
import MixinServices

final class TokenPriceChartCell: UITableViewCell {
    
    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var priceLabel: UILabel!
    @IBOutlet weak var changeLabel: UILabel!
    @IBOutlet weak var tokenIconView: BadgeIconView!
    @IBOutlet weak var chartView: ChartView!
    @IBOutlet weak var loadingIndicatorView: ActivityIndicatorView!
    @IBOutlet weak var periodSelectorStackView: UIStackView!
    
    private weak var unavailableView: UIView?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        titleStackView.setCustomSpacing(9, after: titleLabel)
        titleLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        priceLabel.setFont(scaledFor: .systemFont(ofSize: 22, weight: .medium), adjustForContentSize: true)
        changeLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        chartView.annotateExtremums = true
        for (i, period) in PriceHistory.Period.allCases.enumerated() {
            let button = UIButton(type: .system)
            button.tag = i
            button.setTitle("\(period)", for: .normal)
        }
    }
    
    func showUnavailableView() {
        let unavailableView: UIView
        if let view = self.unavailableView {
            unavailableView = view
        } else {
            unavailableView = UnavailableView()
            contentView.addSubview(unavailableView)
            unavailableView.snp.makeConstraints { make in
                make.top.equalTo(titleStackView.snp.bottom).offset(24)
                make.leading.equalToSuperview().offset(16)
                make.trailing.equalToSuperview().offset(-16)
                make.bottom.equalToSuperview().offset(-20)
            }
            self.unavailableView = unavailableView
        }
        unavailableView.isHidden = false
    }
    
    func hideUnavailableView() {
        unavailableView?.isHidden = true
    }
    
    private class UnavailableView: UIView {
        
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
    
}
