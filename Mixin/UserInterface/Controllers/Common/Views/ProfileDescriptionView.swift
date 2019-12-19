import UIKit

final class ProfileDescriptionView: UIView {
    
    let label = ProfileDescriptionLabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    private func prepare() {
        label.textColor = .text
        label.backgroundColor = .clear
        addSubview(label)
        let inset = UIEdgeInsets(top: 6, left: 28, bottom: 6, right: 28)
        label.snp.makeConstraints { (make) in
            make.edges.equalToSuperview().inset(inset)
        }
    }
    
}
