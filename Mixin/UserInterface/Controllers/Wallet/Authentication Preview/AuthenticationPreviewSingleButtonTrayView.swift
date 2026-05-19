import UIKit

final class AuthenticationPreviewSingleButtonTrayView: UIView {
    
    private(set) weak var button: ConfigurationBasedBusyButton!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadSubview()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadSubview()
    }
    
    private func loadSubview() {
        backgroundColor = R.color.background()
        
        var config: UIButton.Configuration = .filled()
        config.titleTextAttributesTransformer = .init { incoming in
            var outgoing = incoming
            outgoing.font = UIFontMetrics.default.scaledFont(
                for: .systemFont(ofSize: 16)
            )
            outgoing.foregroundColor = .white
            return outgoing
        }
        config.cornerStyle = .capsule
        let button = ConfigurationBasedBusyButton(configuration: config)
        addSubview(button)
        button.snp.makeConstraints { make in
            make.width.greaterThanOrEqualTo(128)
            make.height.greaterThanOrEqualTo(44)
            make.center.equalToSuperview().priority(.almostRequired)
            make.top.equalToSuperview().offset(20)
            make.bottom.equalTo(safeAreaLayoutGuide).offset(-20)
        }
        self.button = button
    }
    
}
