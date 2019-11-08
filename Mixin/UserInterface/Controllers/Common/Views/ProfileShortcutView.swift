import UIKit

final class ProfileShortcutView: UIView, XibDesignable {
    
    @IBOutlet weak var leftShortcutButton: UIButton!
    @IBOutlet weak var sendMessageButton: BusyButton!
    @IBOutlet weak var toggleSizeButton: UIButton!
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadXib()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadXib()
    }
    
    convenience init() {
        let frame = CGRect(x: 0, y: 0, width: 414, height: 66)
        self.init(frame: frame)
    }
    
    private func loadXib() {
        let bundle = Bundle(for: type(of: self))
        guard let view = bundle.loadNibNamed("ProfileShortcutView", owner: self, options: nil)?.first as? UIView else {
            return
        }
        layoutMargins = .zero
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        view.snp.makeConstraints { (make) in
            make.height.equalTo(44)
            make.center.equalToSuperview()
            make.top.equalToSuperview().offset(23)
            make.bottom.equalToSuperview().offset(-23)
        }
    }
    
}
