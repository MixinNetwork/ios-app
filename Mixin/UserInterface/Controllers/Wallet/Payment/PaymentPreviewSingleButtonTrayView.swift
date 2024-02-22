import UIKit

final class PaymentPreviewSingleButtonTrayView: UIView {
    
    let button = UIButton(type: .system)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadSubview()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadSubview()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        button.layer.cornerRadius = button.bounds.height / 2
    }
    
    private func loadSubview() {
        backgroundColor = R.color.background()
        
        button.backgroundColor = R.color.theme()
        button.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 16), adjustForContentSize: true)
        button.setTitleColor(.white, for: .normal)
        button.layer.masksToBounds = true
        addSubview(button)
        button.snp.makeConstraints { make in
            make.width.greaterThanOrEqualTo(128)
            make.height.greaterThanOrEqualTo(44)
            make.center.equalToSuperview().priority(.almostRequired)
            make.top.equalToSuperview().offset(20)
            make.bottom.equalTo(safeAreaLayoutGuide).offset(-20)
        }
    }
    
}
