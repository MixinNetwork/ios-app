import UIKit

final class SeparatorHeaderFooterView: UITableViewHeaderFooterView {
    
    static let reuseIdentifier = "separator"
    
    private let separatorView = UIView()
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        loadSubview()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadSubview()
    }
    
    private func loadSubview() {
        separatorView.backgroundColor = R.color.background_secondary()
        addSubview(separatorView)
        separatorView.snp.makeConstraints { make in
            make.height.equalTo(10)
            make.centerY.leading.trailing.equalToSuperview()
        }
    }
    
}
