import UIKit
import MixinServices

final class TokenReceiverViewController: UIViewController {
    
    private enum Destination: Int, CaseIterable {
        case newAddress = 0
        case contact
        case addressBook
    }
    
    private let token: TokenItem
    private let destinations: [Destination] = Destination.allCases
    
    private weak var tableView: UITableView!
    
    init(token: TokenItem) {
        self.token = token
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = R.string.localizable.send()
        navigationItem.rightBarButtonItem = .customerService(target: self, action: #selector(presentCustomerService(_:)))
        let tableView = UITableView(frame: view.bounds, style: .plain)
        view.addSubview(tableView)
        tableView.snp.makeEdgesEqualToSuperview()
        self.tableView = tableView
        tableView.backgroundColor = R.color.background_secondary()
        tableView.separatorStyle = .none
        tableView.register(R.nib.addressInfoInputCell)
        tableView.register(R.nib.sendingDestinationCell)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.contentInsetAdjustmentBehavior = .always
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 35, right: 0)
    }
    
    @objc private func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController()
        present(customerService, animated: true)
    }
    
}

extension TokenReceiverViewController: HomeNavigationController.NavigationBarStyling {
    
    var navigationBarStyle: HomeNavigationController.NavigationBarStyle {
        .secondaryBackground
    }
    
}

extension TokenReceiverViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        destinations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let destination = Destination(rawValue: indexPath.row)!
        switch destination {
        case .newAddress:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.address_info_input, for: indexPath)!
            cell.load(token: token)
            cell.delegate = self
            return cell
        case .contact:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.sending_destination, for: indexPath)!
            cell.iconImageView.image = R.image.wallet.send_destination_contact()
            cell.titleLabel.text = R.string.localizable.send_to_contact()
            cell.freeLabel.isHidden = false
            cell.subtitleLabel.text = R.string.localizable.send_to_contact_description()
            cell.disclosureIndicatorImageView.isHidden = true
            return cell
        case .addressBook:
            let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.sending_destination, for: indexPath)!
            cell.iconImageView.image = R.image.wallet.send_destination_address()
            cell.titleLabel.text = R.string.localizable.send_to_address()
            cell.freeLabel.isHidden = true
            cell.subtitleLabel.text = R.string.localizable.send_to_address_description()
            cell.disclosureIndicatorImageView.isHidden = true
            return cell
        }
    }
    
}

extension TokenReceiverViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch Destination(rawValue: indexPath.row)! {
        case .newAddress:
            UITableView.automaticDimension
        case .contact, .addressBook:
            74
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Destination(rawValue: indexPath.row)! {
        case .newAddress:
            break
        case .contact:
            let selector = TransferReceiverViewController()
            selector.onSelect = { [token] (user) in
                self.dismiss(animated: true) {
                    let inputAmount = TransferInputAmountViewController(tokenItem: token, receiver: user)
                    self.navigationController?.pushViewController(inputAmount, animated: true)
                }
            }
            self.present(selector, animated: true)
        case .addressBook:
            let book = AddressBookViewController(token: token)
            book.onSelect = { [token] (address) in
                self.dismiss(animated: true) {
                    let inputAmount = WithdrawInputAmountViewController(tokenItem: token, address: address)
                    self.navigationController?.pushViewController(inputAmount, animated: true)
                }
            }
            present(book, animated: true)
        }
    }
    
}

extension TokenReceiverViewController: AddressInfoInputCell.Delegate {
    
    func addressInfoInputCell(_ cell: AddressInfoInputCell, didUpdateContent content: String?) {
        
    }
    
    func addressInfoInputCellWantsToScanContent(_ cell: AddressInfoInputCell) {
        let scanner = CameraViewController.instance()
        scanner.asQrCodeScanner = true
        scanner.delegate = self
        navigationController?.pushViewController(scanner, animated: true)
    }
    
}

extension TokenReceiverViewController: CameraViewControllerDelegate {
    
    func cameraViewController(_ controller: CameraViewController, shouldRecognizeString string: String) -> Bool {
        
        return false
    }
    
}
