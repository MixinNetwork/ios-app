import UIKit
import MixinServices

final class DepositNetworkSelectorViewController: PopupSelectorViewController {
    
    var onDismiss: (() -> Void)?
    
    private let token: MixinTokenItem
    private let chain: Chain
    
    private let headerReuseID = "h"
    private let presentationManager = PopupPresentationManager()
    
    init(token: MixinTokenItem, chain: Chain) {
        self.token = token
        self.chain = chain
        super.init()
        transitioningDelegate = presentationManager
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        titleView.titleLabel.text = R.string.localizable.choose_deposit_network()
        titleView.closeButton.isHidden = true
        tableViewTopConstraint.constant = 0
        tableView.estimatedSectionHeaderHeight = 77
        tableView.rowHeight = 74
        tableView.register(R.nib.depositNetworkCell)
        tableView.register(WarningHeaderView.self, forHeaderFooterViewReuseIdentifier: headerReuseID)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.contentInsetAdjustmentBehavior = .always
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 35, right: 0)
    }
    
}

extension DepositNetworkSelectorViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.deposit_network, for: indexPath)!
        cell.label.text = token.depositNetworkName ?? chain.name
        cell.iconImageView.sd_setImage(with: URL(string: chain.iconUrl))
        return cell
    }
    
}

extension DepositNetworkSelectorViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        tableView.dequeueReusableHeaderFooterView(withIdentifier: headerReuseID)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        presentingViewController?.dismiss(animated: true, completion: onDismiss)
    }
    
}

extension DepositNetworkSelectorViewController {
    
    fileprivate class WarningHeaderView: UITableViewHeaderFooterView {
        
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
            
            let backgroundView = UIView()
            backgroundView.backgroundColor = R.color.background_warning()
            backgroundView.layer.cornerRadius = 8
            backgroundView.layer.masksToBounds = true
            addSubview(backgroundView)
            backgroundView.snp.makeConstraints { make in
                let insets = UIEdgeInsets(top: 0, left: 16, bottom: 11, right: 16)
                make.edges.equalToSuperview().inset(insets)
            }
            
            let stackView = UIStackView()
            stackView.axis = .horizontal
            stackView.spacing = 16
            backgroundView.addSubview(stackView)
            stackView.snp.makeConstraints { make in
                let insets = UIEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)
                make.edges.equalToSuperview().inset(insets)
            }
            
            let imageView = UIImageView(image: R.image.ic_announcement())
            imageView.contentMode = .center
            imageView.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            imageView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
            stackView.addArrangedSubview(imageView)
            
            let label = UILabel()
            label.numberOfLines = 0
            label.textColor = R.color.text()
            label.setFont(scaledFor: .systemFont(ofSize: 14), adjustForContentSize: true)
            label.text = R.string.localizable.choose_network_tip()
            label.setContentHuggingPriority(.defaultLow, for: .horizontal)
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            stackView.addArrangedSubview(label)
        }
        
    }
    
}
