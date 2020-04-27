import UIKit

class LocationInformationView: SolidBackgroundColoredView {
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    
    @IBOutlet weak var trailingPlaceholderWidthConstraint: NSLayoutConstraint!
    
    var contentLeadingConstraint: NSLayoutConstraint!
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadSubviews()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadSubviews()
    }
    
    private func loadSubviews() {
        backgroundColorIgnoringSystemSettings = .background
        let view = Bundle.main.loadNibNamed("LocationInformationView", owner: self, options: nil)!.first as! UIStackView
        layoutMargins = .zero
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        contentLeadingConstraint = view.leadingAnchor.constraint(equalTo: self.leadingAnchor)
        contentLeadingConstraint.isActive = true
        view.snp.makeConstraints { (make) in
            make.top.greaterThanOrEqualToSuperview()
            make.trailing.equalToSuperview().offset(-20)
            make.bottom.equalToSuperview().offset(-9)
        }
    }
    
}
