import UIKit

final class EditFavoriteAppsHeaderView: UITableViewHeaderFooterView {
    
    var descriptionWrapperViewTopConstraint: NSLayoutConstraint!
    
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        loadSubviews()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        loadSubviews()
    }
    
    private func loadSubviews() {
        contentView.backgroundColor = R.color.background()
        
        let descriptionWrapperView = UIView()
        descriptionWrapperView.backgroundColor = R.color.background_secondary()
        contentView.addSubview(descriptionWrapperView)
        descriptionWrapperView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().offset(-20)
        }
        descriptionWrapperViewTopConstraint = descriptionWrapperView.topAnchor
            .constraint(equalTo: contentView.topAnchor, constant: 20)
        descriptionWrapperViewTopConstraint.isActive = true
        
        let label = UILabel()
        label.numberOfLines = 0
        label.textColor = R.color.text_tertiary()
        label.text = R.string.localizable.max_favorite_bots_description()
        label.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        descriptionWrapperView.addSubview(label)
        label.snp.makeConstraints { make in
            let inset = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
            make.edges.equalToSuperview().inset(inset)
        }
    }
    
}
