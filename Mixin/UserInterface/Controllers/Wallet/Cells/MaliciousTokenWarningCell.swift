import UIKit

final class MaliciousTokenWarningCell: UITableViewCell {
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        prepare()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        prepare()
    }
    
    private func prepare() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        let view = R.nib.maliciousWarningView(withOwner: nil)!
        view.content = .token
        contentView.addSubview(view)
        view.snp.makeEdgesEqualToSuperview()
    }
    
}
