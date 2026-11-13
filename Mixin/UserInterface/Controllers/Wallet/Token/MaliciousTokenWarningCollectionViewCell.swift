import UIKit

final class MaliciousTokenWarningCollectionViewCell: UICollectionViewCell {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        let warning = R.nib.maliciousWarningView(withOwner: nil)!
        warning.content = .token
        contentView.addSubview(warning)
        warning.snp.makeEdgesEqualToSuperview()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard/Xib not supported")
    }
    
}
