import UIKit

protocol SelectedItemCellDelegate: AnyObject {
    func selectedItemCellDidSelectRemove(_ cell: UICollectionViewCell)
}

class SelectedItemCell<IconView: UIView>: UICollectionViewCell {
    
    let iconView = IconView()
    let removeButton = UIButton(type: .system)
    let nameLabel = UILabel()
    
    weak var delegate: SelectedItemCellDelegate?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadSubviews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadSubviews()
    }
    
    @objc private func remove(_ sender: Any) {
        delegate?.selectedItemCellDidSelectRemove(self)
    }
    
    func loadSubviews() {
        contentView.backgroundColor = R.color.background()
        
        iconView.backgroundColor = R.color.background()
        contentView.addSubview(iconView)
        iconView.snp.makeConstraints { make in
            make.width.height.equalTo(50)
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(2)
        }
        
        nameLabel.setFont(scaledFor: .systemFont(ofSize: 14),
                          adjustForContentSize: true)
        nameLabel.textColor = R.color.text()
        nameLabel.textAlignment = .center
        contentView.addSubview(nameLabel)
        nameLabel.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.greaterThanOrEqualTo(iconView.snp.bottom)
        }
        
        let removeImage = R.image.ic_circle_member_remove()?.withRenderingMode(.alwaysOriginal)
        removeButton.setImage(removeImage, for: .normal)
        addSubview(removeButton)
        removeButton.addTarget(self, action: #selector(remove(_:)), for: .touchUpInside)
        removeButton.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.trailing.equalTo(iconView.snp.trailing).offset(-2)
        }
    }
    
}
