import UIKit

final class ConfigurationBasedBusyButton: UIButton {
    
    private let busyIndicator = ActivityIndicatorView()
    
    private var normalConfiguration: UIButton.Configuration?
    
    var isBusy = false {
        didSet {
            if isBusy {
                normalConfiguration = self.configuration
                configuration?.baseForegroundColor = .clear
                configuration?.image = nil
                busyIndicator.startAnimating()
                isUserInteractionEnabled = false
            } else {
                if let normalConfiguration {
                    configuration = normalConfiguration
                }
                busyIndicator.stopAnimating()
                isUserInteractionEnabled = true
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadSubviews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadSubviews()
    }
    
    private func loadSubviews() {
        busyIndicator.tintColor = .white
        busyIndicator.backgroundColor = .clear
        busyIndicator.hidesWhenStopped = true
        busyIndicator.stopAnimating()
        addSubview(busyIndicator)
        busyIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }
    
}
