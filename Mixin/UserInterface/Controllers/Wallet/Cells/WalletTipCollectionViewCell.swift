import UIKit

final class WalletTipCollectionViewCell: UICollectionViewCell {
    
    let tipView = R.nib.walletTipView(withOwner: nil)!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        prepare()
    }
    
    private func prepare() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        contentView.addSubview(tipView)
        tipView.snp.makeEdgesEqualToSuperview()
    }
    
}
