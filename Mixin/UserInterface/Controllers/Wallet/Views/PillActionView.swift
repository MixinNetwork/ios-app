import UIKit

final class PillActionView: UIView {
    
    protocol Delegate: AnyObject {
        func pillActionView(_ view: PillActionView, didSelectActionAtIndex index: Int)
    }
    
    var actions: [String] = [] {
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
    
    private func reloadData(actions: [String]) {
        for view in stackView.arrangedSubviews {
            view.removeFromSuperview()
        }
        for (i, action) in actions.enumerated() {
            let button = UIButton(type: .system)
            button.tag = i
            button.addTarget(self, action: #selector(invokeAction(_:)), for: .touchUpInside)
            button.setTitle(action, for: .normal)
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
        delegate?.pillActionView(self, didSelectActionAtIndex: button.tag)
    }
    
}
