import UIKit
import MixinServices

final class PaymentCollectibleSelectorViewController: PopupSelectorViewController {
    
    private let receiver: UserItem
    private let collectionHash: String
    private let collectionIconImageView = UIImageView()
    private let searchBoxView = SearchBoxView()
    
    private var inscriptions: [InscriptionOutput] = []
    private var inscriptionSearchResults: [InscriptionOutput]?
    
    private var items: [InscriptionOutput] {
        inscriptionSearchResults ?? inscriptions
    }
    
    init(receiver: UserItem, collectionHash: String) {
        self.receiver = receiver
        self.collectionHash = collectionHash
        super.init()
        transitioningDelegate = nil
        modalPresentationStyle = .automatic
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleView.contentStackView.insertArrangedSubview(collectionIconImageView, at: 0)
        collectionIconImageView.backgroundColor = R.color.background()
        collectionIconImageView.snp.makeConstraints { make in
            make.width.height.equalTo(36)
        }
        collectionIconImageView.mask = {
            let mask = UIImageView(image: R.image.collection_token_mask())
            mask.contentMode = .scaleAspectFit
            mask.frame = CGRect(x: 0, y: 0, width: 36, height: 36)
            return mask
        }()
        titleView.titleLabel.text = R.string.localizable.send_collectible()
        titleView.subtitleLabel.text = nil
        
        view.addSubview(searchBoxView)
        searchBoxView.snp.makeConstraints { make in
            make.top.equalTo(titleView.snp.bottom)
            make.leading.equalToSuperview().offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.height.equalTo(44)
        }
        searchBoxView.textField.addTarget(self, action: #selector(searchCollectible(_:)), for: .editingChanged)
        searchBoxView.textField.placeholder = "ID"
        searchBoxView.textField.keyboardType = .asciiCapableNumberPad
        tableViewTopConstraint.constant = 54
        
        tableView.rowHeight = 70
        tableView.register(R.nib.paymentCollectibleCell)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 40, right: 0)
        tableView.isScrollEnabled = true
        tableView.alwaysBounceVertical = true
        tableView.keyboardDismissMode = .onDrag
        
        DispatchQueue.global().async { [collectionHash, weak self] in
            let inscriptions = InscriptionDAO.shared.inscriptionOutputs(collectionHash: collectionHash)
            let collection = InscriptionDAO.shared.collection(hash: collectionHash)
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                if let collection {
                    if let url = URL(string: collection.iconURL) {
                        self.collectionIconImageView.sd_setImage(with: url)
                    }
                    self.titleView.subtitleLabel.text = collection.name
                }
                self.inscriptions = inscriptions
                self.tableView.reloadData()
                self.tableView.checkEmpty(
                    dataCount: inscriptions.count,
                    text: R.string.localizable.no_collectibles(),
                    photo: R.image.inscription_relief()!
                )
            }
        }
    }
    
    override func updatePreferredContentHeight() {
        // We're using UIModalPresentationStyle.automatic, better do nothing to preferredContentSize
    }
    
    @objc func searchCollectible(_ textField: UITextField) {
        defer {
            tableView.reloadData()
            tableView.checkEmpty(
                dataCount: items.count,
                text: R.string.localizable.no_collectibles(),
                photo: R.image.inscription_relief()!
            )
        }
        let trimmedLowercaseKeyword = (textField.text ?? "")
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
        guard !trimmedLowercaseKeyword.isEmpty else {
            inscriptionSearchResults = nil
            return
        }
        guard let sequence = UInt64(trimmedLowercaseKeyword) else {
            inscriptionSearchResults = []
            return
        }
        inscriptionSearchResults = inscriptions.filter { item in
            item.inscription?.sequence == sequence
        }
    }
    
}

extension PaymentCollectibleSelectorViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.payment_collectible, for: indexPath)!
        let inscription = items[indexPath.row]
        cell.load(item: inscription)
        return cell
    }
    
}

extension PaymentCollectibleSelectorViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let presentingViewController else {
            return
        }
        let inscription = items[indexPath.row]
        presentingViewController.dismiss(animated: true) { [receiver] in
            let output = inscription.output
            guard
                let item = inscription.inscription,
                let token = TokenDAO.shared.tokenItem(kernelAssetID: output.asset),
                let context = Payment.InscriptionContext(operation: .transfer, output: output, item: item)
            else {
                return
            }
            let traceID = UUID().uuidString.lowercased()
            let payment: Payment = .inscription(traceID: traceID, token: token, memo: "", context: context)
            payment.checkPreconditions(
                transferTo: .user(receiver),
                reference: nil,
                on: presentingViewController
            ) { reason in
                switch reason {
                case .userCancelled, .loggedOut:
                    break
                case .description(let message):
                    showAutoHiddenHud(style: .error, text: message)
                }
            } onSuccess: { operation, issues in
                let preview = TransferPreviewViewController(issues: issues,
                                                            operation: operation,
                                                            amountDisplay: .byToken,
                                                            redirection: nil)
                presentingViewController.present(preview, animated: true)
            }
        }
    }
    
}
