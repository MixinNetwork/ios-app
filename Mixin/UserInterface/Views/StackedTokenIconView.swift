import UIKit
import MixinServices

final class StackedTokenIconView: UIView {
    
    enum Size {
        case large
        case small
    }
    
    var size: Size = .small
    
    private typealias IconWrapperView = StackedIconWrapperView<PlainTokenIconView>
    
    private let stackView = UIStackView()
    
    private var wrapperViews: [IconWrapperView] = []
    
    private var iconWrapperFrame: CGRect {
        CGRect(x: 0, y: 0, width: bounds.height, height: bounds.height)
    }
    
    private var spacing: CGFloat {
        switch size {
        case .large:
            16
        case .small:
            6
        }
    }
    
    private weak var addtionalCountLabel: InsetLabel?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadSubviews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadSubviews()
    }
    
    func setIcons(urls: [String]) {
        if urls.count > 3 {
            loadIconViews(count: 2) { _, wrapperView in
                wrapperView.snp.makeConstraints { make in
                    make.width.equalTo(wrapperView.snp.height).offset(-spacing)
                }
            }
            let label: InsetLabel
            if let l = addtionalCountLabel {
                label = l
            } else {
                let view = StackedIconWrapperView<RoundedInsetLabel>(margin: 2, frame: iconWrapperFrame)
                view.backgroundColor = .clear
                label = view.iconView
                label.backgroundColor = R.color.background_quaternary()
                label.textColor = R.color.icon_tint_tertiary()
                label.textAlignment = .center
                switch size {
                case .large:
                    label.font = .systemFont(ofSize: 20)
                    label.contentInset = .zero
                case .small:
                    label.font = .systemFont(ofSize: 8)
                    label.contentInset = UIEdgeInsets(top: 0, left: 1, bottom: 0, right: 2)
                }
                label.adjustsFontSizeToFitWidth = true
                label.minimumScaleFactor = 0.1
                label.layer.masksToBounds = true
                stackView.addArrangedSubview(view)
                view.snp.makeConstraints { make in
                    make.height.equalToSuperview()
                    make.width.equalTo(view.snp.height)
                }
                self.addtionalCountLabel = label
            }
            label.text = "+\(min(99, urls.count - 2))"
        } else {
            loadIconViews(count: urls.count) { index, wrapperView in
                let offset = index == urls.count - 1 ? 0 : -spacing
                wrapperView.snp.makeConstraints { make in
                    make.width.equalTo(wrapperView.snp.height).offset(offset)
                }
            }
        }
        for (i, wrapperView) in wrapperViews.enumerated() {
            let url = URL(string: urls[i])
            wrapperView.iconView.setIcon(tokenIconURL: url)
        }
    }
    
    func setIcon(sendToken: any Token, receiveToken: any Token) {
        loadIconViews(count: 2) { index, wrapperView in
            let offset = index == 1 ? 0 : -spacing
            wrapperView.snp.makeConstraints { make in
                make.width.equalTo(wrapperView.snp.height).offset(offset)
            }
        }
        wrapperViews[0].iconView.setIcon(token: sendToken)
        wrapperViews[1].iconView.setIcon(token: receiveToken)
    }
    
    private func loadIconViews(count: Int, makeConstraints maker: (Int, IconWrapperView) -> Void) {
        guard wrapperViews.count != count else {
            return
        }
        for view in stackView.arrangedSubviews {
            view.removeFromSuperview()
        }
        wrapperViews = []
        for i in 0..<count {
            let view = IconWrapperView(margin: 2, frame: iconWrapperFrame)
            view.backgroundColor = .clear
            stackView.addArrangedSubview(view)
            wrapperViews.append(view)
            maker(i, view)
        }
    }
    
    private func loadSubviews() {
        backgroundColor = R.color.background()
        addSubview(stackView)
        stackView.snp.makeEdgesEqualToSuperview()
    }
    
    private final class RoundedInsetLabel: InsetLabel {
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            layer.masksToBounds = true
            layer.cornerRadius = frame.height / 2
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            layer.masksToBounds = true
            layer.cornerRadius = bounds.height / 2
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            layer.cornerRadius = bounds.height / 2
        }
        
    }
    
}
