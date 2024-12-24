import UIKit

final class StackedIconWrapperView<IconView: UIView>: UIView {
    
    let iconView = IconView()
    
    private let backgroundView = UIView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadIconView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadIconView()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundView.layer.cornerRadius = bounds.height / 2
    }
    
    private func loadIconView() {
        addSubview(backgroundView)
        backgroundView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.width.equalTo(backgroundView.snp.height)
        }
        backgroundView.backgroundColor = R.color.background()
        backgroundView.layer.cornerRadius = bounds.height / 2
        backgroundView.layer.masksToBounds = true
        
        addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(1)
            make.top.equalToSuperview().offset(1)
            make.bottom.equalToSuperview().offset(-1)
            make.width.equalTo(iconView.snp.height)
        }
    }
    
}
