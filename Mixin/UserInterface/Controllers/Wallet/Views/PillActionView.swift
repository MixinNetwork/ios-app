import UIKit

final class PillActionView: UIView {
    
    protocol Delegate: AnyObject {
        func pillActionView(_ view: PillActionView, didSelectActionAtIndex index: Int)
    }
    
    struct Action: Equatable {
        
        enum Style {
            case normal
            case destructive
            case vibrant
            case filled
        }
        
        let title: String
        let style: Style
        
        init(title: String, style: Style = .normal) {
            self.title = title
            self.style = style
        }
        
    }
    
    var actions: [Action] = [] {
        didSet {
            guard actions != oldValue else {
                return
            }
            reloadData(actions: actions)
        }
    }
    
    weak var delegate: Delegate?
    
    private weak var stackView: UIStackView!
    
    private var separatorLines: [UIView] = []
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        loadSubviews()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadSubviews()
    }
    
    private func loadSubviews() {
        let stackView = UIStackView(frame: bounds)
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .fillEqually
        addSubview(stackView)
        stackView.snp.makeEdgesEqualToSuperview()
        self.stackView = stackView
    }
    
    private func reloadData(actions: [Action]) {
        for view in stackView.arrangedSubviews {
            view.removeFromSuperview()
        }
        for (i, action) in actions.enumerated() {
            let button = UIButton(type: .system)
            button.tag = i
            button.addTarget(self, action: #selector(invokeAction(_:)), for: .touchUpInside)
            var configuration: UIButton.Configuration = .plain()
            switch action.style {
            case .normal:
                configuration.baseBackgroundColor = R.color.background_quaternary()
                configuration.baseForegroundColor = R.color.text()
            case .destructive:
                configuration.baseBackgroundColor = R.color.background_quaternary()
                configuration.baseForegroundColor = R.color.error_red()
            case .vibrant:
                configuration.baseBackgroundColor = R.color.background_quaternary()
                configuration.baseForegroundColor = R.color.theme()
            case .filled:
                configuration.baseBackgroundColor = R.color.theme()
                configuration.baseForegroundColor = .white
            }
            var attributes = AttributeContainer()
            attributes.font = UIFontMetrics.default.scaledFont(
                for: .systemFont(ofSize: 16, weight: .semibold)
            )
            configuration.attributedTitle = AttributedString(action.title, attributes: attributes)
            button.configuration = configuration
            stackView.addArrangedSubview(button)
        }
        
        for line in separatorLines {
            line.removeFromSuperview()
        }
        for i in 1..<actions.count {
            let line = UIView()
            line.backgroundColor = R.color.transfer_line_background()
            addSubview(line)
            line.snp.makeConstraints { make in
                make.width.equalTo(2)
                make.height.equalTo(20)
                make.centerY.equalToSuperview()
                make.centerX.equalTo(snp.trailing)
                    .multipliedBy(CGFloat(i) / CGFloat(actions.count))
            }
            separatorLines.append(line)
        }
    }
    
    @objc private func invokeAction(_ button: UIButton) {
        delegate?.pillActionView(self, didSelectActionAtIndex: button.tag)
    }
    
}
