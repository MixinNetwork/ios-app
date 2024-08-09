import UIKit

protocol TransferActionViewDelegate: AnyObject {
    func transferActionView(_ view: TransferActionView, didSelect action: TransferActionView.Action)
}

final class TransferActionView: UIView {
    
    enum Action: Int {
        case send
        case receive
        case swap
    }
    
    var actions: [Action] = [] {
        didSet {
            guard actions != oldValue else {
                return
            }
            reloadData(actions: actions)
        }
    }
    
    weak var delegate: TransferActionViewDelegate?
    
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
        for action in actions {
            let button = UIButton(type: .system)
            button.tag = action.rawValue
            button.addTarget(self, action: #selector(invokeAction(_:)), for: .touchUpInside)
            switch action {
            case .send:
                button.setTitle(R.string.localizable.caption_send(), for: .normal)
            case .receive:
                button.setTitle(R.string.localizable.receive(), for: .normal)
            case .swap:
                button.setTitle(R.string.localizable.swap(), for: .normal)
            }
            button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
            button.setTitleColor(R.color.text(), for: .normal)
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
        guard let action = Action(rawValue: button.tag) else {
            return
        }
        delegate?.transferActionView(self, didSelect: action)
    }
    
}
