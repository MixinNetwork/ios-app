import UIKit
import web3
import MixinServices

final class Web3SendingDestinationViewController: KeyboardBasedLayoutViewController {
    
    private enum InputAction {
        case scan
        case clear
    }
    
    private enum Destination {
        case myMixinWallet(_ mixinChainID: String)
    }
    
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var placeholderLabel: UILabel!
    @IBOutlet weak var inputActionButton: UIButton!
    @IBOutlet weak var invalidAddressLabel: UILabel!
    @IBOutlet weak var separatorLineView: UIView!
    @IBOutlet weak var segmentsCollectionView: UICollectionView!
    
    @IBOutlet weak var textViewHeightConstraint: NSLayoutConstraint!
    
    private let payment: Web3SendingTokenPayment
    private let destinations: [Destination]
    private let tableView = UITableView()
    
    private weak var tableHeaderView: UIView?
    private weak var trayView: AuthenticationPreviewSingleButtonTrayView?
    private weak var trayViewBottomConstraint: NSLayoutConstraint?
    
    private var isTextViewEditing = false {
        didSet {
            layoutSubviews(isTextViewEditing: isTextViewEditing)
        }
    }
    
    private var inputAction: InputAction = .scan {
        didSet {
            switch inputAction {
            case .scan:
                inputActionButton.setImage(R.image.explore.web3_send_scan(), for: .normal)
            case .clear:
                inputActionButton.setImage(R.image.explore.web3_send_delete(), for: .normal)
            }
        }
    }
    
    private var continueButton: StateResponsiveButton? {
        trayView?.button
    }
    
    init(payment: Web3SendingTokenPayment) {
        self.payment = payment
        if let chainID = payment.chain.mixinChainID {
            self.destinations = [.myMixinWallet(chainID)]
        } else {
            self.destinations = []
        }
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableHeaderView = R.nib.web3SendingDestinationHeaderView(withOwner: self)
        view.addSubview(tableView)
        tableView.backgroundColor = R.color.background()
        tableView.snp.makeEdgesEqualToSuperview()
        tableView.rowHeight = 57
        tableView.separatorStyle = .none
        tableView.register(R.nib.web3AccountCell)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.tableHeaderView = tableHeaderView
        tableView.reloadData()
        
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.delegate = self
        
        segmentsCollectionView.register(R.nib.exploreSegmentCell)
        if let layout = segmentsCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.scrollDirection = .horizontal
            layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
            layout.minimumInteritemSpacing = 0
        }
        segmentsCollectionView.contentInset = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 15)
        segmentsCollectionView.dataSource = self
        segmentsCollectionView.reloadData()
        segmentsCollectionView.selectItem(at: IndexPath(item: 0, section: 0),
                                          animated: false,
                                          scrollPosition: .left)
        
        layoutSubviews(isTextViewEditing: false)
    }
    
    override func layout(for keyboardFrame: CGRect) {
        guard let constraint = trayViewBottomConstraint else {
            return
        }
        constraint.constant = view.frame.height - keyboardFrame.origin.y
        view.layoutIfNeeded()
    }
    
    @IBAction func performInputAction(_ sender: Any) {
        switch inputAction {
        case .scan:
            textView.becomeFirstResponder()
            let scanner = CameraViewController.instance()
            scanner.asQrCodeScanner = true
            scanner.delegate = self
            navigationController?.pushViewController(scanner, animated: true)
        case .clear:
            textView.text = ""
            textViewDidChange(textView)
        }
    }
    
    @objc private func continueWithAddress(_ sender: Any) {
        let address: String?
        switch payment.chain.kind {
        case .evm:
            let ethereumAddress = EthereumAddress(textView.text)
            if textView.text.count != 42 || ethereumAddress.asNumber() == nil {
                address = nil
            } else {
                address = ethereumAddress.toChecksumAddress()
            }
        case .solana:
            if Solana.isValidPublicKey(string: textView.text) {
                address = textView.text
            } else {
                address = nil
            }
        }
        if let address {
            let payment = Web3SendingTokenToAddressPayment(
                payment: payment,
                to: .arbitrary,
                address: address
            )
            let input = Web3TransferInputAmountViewController(payment: payment)
            let container = ContainerViewController.instance(viewController: input, title: R.string.localizable.send())
            navigationController?.pushViewController(container, animated: true)
        } else {
            invalidAddressLabel.isHidden = false
            continueButton?.isEnabled = false
        }
    }
    
    private func layoutSubviews(isTextViewEditing: Bool) {
        UIView.transition(with: tableView,
                          duration: 0.25,
                          options: .transitionCrossDissolve,
                          animations: tableView.reloadData)
        let hideFixedDestinations = isTextViewEditing || destinations.isEmpty
        UIView.animate(withDuration: 0.25) {
            let alpha: CGFloat = hideFixedDestinations ? 0 : 1
            self.segmentsCollectionView.alpha = alpha
            self.separatorLineView.alpha = alpha
        }
        if isTextViewEditing, trayView == nil {
            let trayView = AuthenticationPreviewSingleButtonTrayView()
            trayView.button.setTitle(R.string.localizable.continue(), for: .normal)
            trayView.button.addTarget(self, action: #selector(continueWithAddress(_:)), for: .touchUpInside)
            view.addSubview(trayView)
            trayView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
            }
            self.trayView = trayView
            let trayViewBottomConstraint = view.bottomAnchor.constraint(equalTo: trayView.bottomAnchor)
            trayViewBottomConstraint.isActive = true
            self.trayViewBottomConstraint = trayViewBottomConstraint
        } else if !isTextViewEditing, let trayView {
            UIView.animate(withDuration: 0.25) {
                trayView.alpha = 0
            } completion: { _ in
                trayView.removeFromSuperview()
            }
        }
    }
    
}

extension Web3SendingDestinationViewController: UITextViewDelegate {
    
    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        isTextViewEditing = true
        return true
    }
    
    func textViewDidChange(_ textView: UITextView) {
        let sizeToFit = CGSize(width: textView.frame.width,
                               height: UIView.layoutFittingExpandedSize.height)
        let newHeight = ceil(textView.sizeThatFits(sizeToFit).height)
        if textViewHeightConstraint.constant != newHeight {
            textViewHeightConstraint.constant = newHeight
            if let tableHeaderView {
                UIView.animate(withDuration: 0.2) {
                    let sizeToFit = CGSize(width: tableHeaderView.frame.width,
                                           height: UIView.layoutFittingExpandedSize.height)
                    tableHeaderView.frame.size.height = tableHeaderView.systemLayoutSizeFitting(sizeToFit).height
                }
                tableView.tableHeaderView = tableHeaderView
            }
        }
        inputAction = textView.text.isEmpty ? .scan : .clear
        placeholderLabel.isHidden = !textView.text.isEmpty 
        invalidAddressLabel.isHidden = true
        continueButton?.isEnabled = true
    }
    
}

extension Web3SendingDestinationViewController: CameraViewControllerDelegate {
    
    func cameraViewController(_ controller: CameraViewController, shouldRecognizeString string: String) -> Bool {
        textView.text = string
        textViewDidChange(textView)
        return false
    }
    
}

extension Web3SendingDestinationViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.explore_segment, for: indexPath)!
        cell.label.text = R.string.localizable.accounts()
        return cell
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        1
    }
    
}

extension Web3SendingDestinationViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        isTextViewEditing ? 0 : destinations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.web3_account, for: indexPath)!
        let destination = destinations[indexPath.row]
        switch destination {
        case .myMixinWallet:
            cell.iconImageView.image = R.image.mixin_wallet()
            cell.titleLabel.text = R.string.localizable.to_mixin_wallet()
            cell.subtitleLabel.text = R.string.localizable.contact_mixin_id(myIdentityNumber)
        }
        return cell
    }
    
}

extension Web3SendingDestinationViewController: UIScrollViewDelegate {
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        guard scrollView == tableView, textView.isFirstResponder else {
            return
        }
        isTextViewEditing = false
        textView.resignFirstResponder()
    }
    
}

extension Web3SendingDestinationViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let destination = destinations[indexPath.row]
        switch destination {
        case .myMixinWallet(let chainID):
            sendToMyMixinWallet(chainID: chainID)
        }
    }
    
}

extension Web3SendingDestinationViewController {
    
    private enum PaymentError: Error {
        case noValidEntry
    }
    
    private func sendToMyMixinWallet(chainID: String) {
        continueButton?.isBusy = true
        Task { [payment, weak self] in
            do {
                let entries = try await SafeAPI.depositEntries(chainID: chainID)
                if let entry = entries.first(where: { $0.chainID == chainID && $0.isPrimary }) {
                    let payment = Web3SendingTokenToAddressPayment(
                        payment: payment,
                        to: .mixinWallet,
                        address: entry.destination
                    )
                    await MainActor.run {
                        guard let self else {
                            return
                        }
                        self.continueButton?.isBusy = false
                        let input = Web3TransferInputAmountViewController(payment: payment)
                        let container = ContainerViewController.instance(viewController: input, title: R.string.localizable.send())
                        self.navigationController?.pushViewController(container, animated: true)
                    }
                } else {
                    throw PaymentError.noValidEntry
                }
            } catch {
                await MainActor.run {
                    guard let self else {
                        return
                    }
                    showAutoHiddenHud(style: .error, text: error.localizedDescription)
                    self.continueButton?.isBusy = false
                }
            }
        }
    }
    
}
