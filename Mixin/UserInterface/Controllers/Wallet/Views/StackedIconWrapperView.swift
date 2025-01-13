import UIKit

final class StackedIconWrapperView<IconView: UIView>: UIView {
    
    let iconView = IconView()
    
    private let backgroundView = UIView()
    private let margin: CGFloat
    
    init(margin: CGFloat, frame: CGRect) {
        self.margin = margin
        super.init(frame: frame)
        loadIconView()
    }
    
    override init(frame: CGRect) {
        self.margin = 1
        super.init(frame: frame)
        loadIconView()
    }
    
    required init?(coder: NSCoder) {
        self.margin = 1
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
            make.leading.equalToSuperview().offset(margin)
            make.top.equalToSuperview().offset(margin)
            make.bottom.equalToSuperview().offset(-margin)
            make.width.equalTo(iconView.snp.height)
        }
    }
    
}
