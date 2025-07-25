import UIKit

class ErrorReportingPINValidationViewController: FullscreenPINValidationViewController {
    
    override var isBusy: Bool {
        didSet {
            if isBusy {
                errorDescriptionLabel?.isHidden = true
            }
        }
    }
    
    private weak var errorDescriptionLabel: UILabel?
    
    func handle(error: Error) {
        isBusy = false
        pinField.clear()
        let label: UILabel
        if let l = errorDescriptionLabel {
            label = l
            label.isHidden = false
        } else {
            label = UILabel()
            label.font = UIFontMetrics.default.scaledFont(for: .systemFont(ofSize: 14))
            label.adjustsFontForContentSizeCategory = true
            label.textColor = R.color.error_red()
            label.textAlignment = .center
            label.numberOfLines = 0
            contentStackView.addArrangedSubview(label)
            label.snp.makeConstraints { make in
                make.width.equalToSuperview().offset(-40)
            }
            errorDescriptionLabel = label
        }
        label.text = error.localizedDescription
    }
    
}
