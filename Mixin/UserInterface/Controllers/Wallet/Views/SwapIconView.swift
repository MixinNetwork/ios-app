import UIKit
import MixinServices

final class SwapIconView: UIView {
    
    enum Size {
        case large
        case medium
    }
    
    var size: Size = .medium {
        didSet {
            layout(size: size)
        }
    }
    
    private var payTokenIconView = PlainTokenIconView(frame: .zero)
    private var payTokenDimensionConstraint: NSLayoutConstraint!
    
    private var receiveBackgroundView = UIView()
    private var receiveBackgroundDimensionConstraint: NSLayoutConstraint!
    
    private var receiveTokenIconView = PlainTokenIconView(frame: .zero)
    private var receiveTokenDimensionConstraint: NSLayoutConstraint!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadSubviews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadSubviews()
    }
    
    func prepareForReuse() {
        payTokenIconView.prepareForReuse()
        receiveTokenIconView.prepareForReuse()
    }
    
    func setTokenIcon(payToken: (any Token)?, receiveToken: (any Token)?) {
        payTokenIconView.setIcon(token: payToken)
        receiveTokenIconView.setIcon(token: receiveToken)
    }
    
    private func layout(size: Size) {
        switch size {
        case .large:
            payTokenDimensionConstraint.constant = 48
            receiveBackgroundDimensionConstraint.constant = 56
            receiveBackgroundView.layer.cornerRadius = 28
            receiveTokenDimensionConstraint.constant = 50
        case .medium:
            payTokenDimensionConstraint.constant = 30
            receiveBackgroundDimensionConstraint.constant = 34
            receiveBackgroundView.layer.cornerRadius = 17
            receiveTokenDimensionConstraint.constant = 30
        }
    }
    
    private func loadSubviews() {
        addSubview(payTokenIconView)
        payTokenIconView.snp.makeConstraints { make in
            make.top.leading.equalToSuperview()
            make.width.equalTo(payTokenIconView.snp.height)
        }
        payTokenDimensionConstraint = payTokenIconView.widthAnchor.constraint(equalToConstant: 30)
        
        receiveBackgroundView.backgroundColor = R.color.background()
        addSubview(receiveBackgroundView)
        receiveBackgroundView.snp.makeConstraints { make in
            make.trailing.bottom.equalToSuperview()
            make.width.equalTo(receiveBackgroundView.snp.height)
        }
        receiveBackgroundDimensionConstraint = receiveBackgroundView.widthAnchor.constraint(equalToConstant: 34)
        receiveBackgroundView.layer.cornerRadius = 17
        receiveBackgroundView.layer.masksToBounds = true
        
        receiveBackgroundView.addSubview(receiveTokenIconView)
        receiveTokenIconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(receiveTokenIconView.snp.height)
        }
        receiveTokenDimensionConstraint = receiveTokenIconView.widthAnchor.constraint(equalToConstant: 30)
        
        NSLayoutConstraint.activate([
            payTokenDimensionConstraint,
            receiveBackgroundDimensionConstraint,
            receiveTokenDimensionConstraint,
        ])
    }
    
}
