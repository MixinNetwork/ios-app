import UIKit
import MixinServices

final class AddressBookCell: UITableViewCell {
    
    static let reuseIdentifier = "address_book"
    
    private let cardView = UIView()
    private let nameLabel = UILabel()
    private let networkIconView = PlainTokenIconView(frame: .zero)
    private let networkLabel = UILabel()
    private let addressLabel = UILabel()
    private let dateLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        loadSubviews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadSubviews()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        networkIconView.prepareForReuse()
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        cardView.backgroundColor = highlighted ? .selectionBackground : R.color.background()
    }
    
    func load(address: Address, network: AddressBookNetwork?) {
        nameLabel.text = address.label
        if let chain = network?.chain {
            networkIconView.setIcon(urlString: chain.iconUrl)
        } else {
            networkIconView.image = R.image.unknown_session()
        }
        networkLabel.text = network?.name
        addressLabel.text = address.fullRepresentation
        let date = DateFormatter.dateFull.string(from: address.updatedAt.toUTCDate())
        dateLabel.text = R.string.localizable.last_updated_at(date)
    }
    
    private func loadSubviews() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none
        
        cardView.backgroundColor = R.color.background()
        cardView.layer.cornerRadius = 8
        cardView.layer.masksToBounds = true
        contentView.addSubview(cardView)
        cardView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 5, left: 20, bottom: 5, right: 20))
        }
        
        nameLabel.textColor = R.color.text()
        nameLabel.setFont(scaledFor: .systemFont(ofSize: 16), adjustForContentSize: true)
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        networkLabel.textColor = R.color.text_tertiary()
        networkLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        networkLabel.setContentHuggingPriority(.required, for: .horizontal)
        networkLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        networkIconView.snp.makeConstraints { make in
            make.width.height.equalTo(18)
        }
        let networkStackView = UIStackView(arrangedSubviews: [networkIconView, networkLabel])
        networkStackView.axis = .horizontal
        networkStackView.alignment = .center
        networkStackView.spacing = 4
        
        let titleStackView = UIStackView(arrangedSubviews: [nameLabel, networkStackView])
        titleStackView.axis = .horizontal
        titleStackView.alignment = .center
        titleStackView.spacing = 8
        
        addressLabel.textColor = R.color.text_tertiary()
        addressLabel.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
        addressLabel.numberOfLines = 0
        addressLabel.lineBreakMode = .byCharWrapping
        
        dateLabel.textColor = R.color.text_quaternary()
        dateLabel.setFont(scaledFor: .systemFont(ofSize: 12), adjustForContentSize: true)
        
        let contentStackView = UIStackView(arrangedSubviews: [titleStackView, addressLabel, dateLabel])
        contentStackView.axis = .vertical
        contentStackView.spacing = 6
        cardView.addSubview(contentStackView)
        contentStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }
    }
    
}
