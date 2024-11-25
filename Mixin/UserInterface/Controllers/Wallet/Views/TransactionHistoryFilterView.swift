import UIKit

class TransactionHistoryFilterView: UIView {
    
    let contentStackView = UIStackView()
    let label = UILabel()
    let button = UIButton()
    
    private let outlineColor = R.color.outline_primary()!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadSubviews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadSubviews()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            layer.borderColor = outlineColor.resolvedColor(with: traitCollection).cgColor
        }
    }
    
    func loadSubviews() {
        layer.cornerRadius = 19
        layer.masksToBounds = true
        layer.borderWidth = 1
        layer.borderColor = outlineColor.cgColor
        
        contentStackView.spacing = 4
        contentStackView.axis = .horizontal
        contentStackView.alignment = .center
        addSubview(contentStackView)
        contentStackView.snp.makeConstraints { make in
            let insets = UIEdgeInsets(top: 9, left: 14, bottom: 9, right: 14)
            make.edges.equalToSuperview().inset(insets)
            make.height.equalTo(20)
        }
        
        label.font = .systemFont(ofSize: 14)
        label.textColor = R.color.text()
        contentStackView.addArrangedSubview(label)
        contentStackView.setCustomSpacing(6, after: label)
        
        let imageView = UIImageView(image: R.image.arrow_down_compact())
        imageView.tintColor = R.color.chat_pin_count_background()
        imageView.contentMode = .center
        contentStackView.addArrangedSubview(imageView) 
        
        button.backgroundColor = .clear
        button.showsMenuAsPrimaryAction = true
        addSubview(button)
        button.snp.makeEdgesEqualToSuperview()
    }
    
}

extension TransactionHistoryFilterView {
    
    class IconWrapperView<IconView: UIView>: UIView {
        
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
    
}
