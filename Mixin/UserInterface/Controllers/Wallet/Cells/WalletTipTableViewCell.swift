import UIKit

final class WalletTipTableViewCell: ModernSelectedBackgroundCell {
    
    let tipView = R.nib.walletTipView(withOwner: nil)!
    
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
        contentView.addSubview(tipView)
        tipView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(15)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.bottom.equalToSuperview().offset(-15)
        }
    }
    
}
