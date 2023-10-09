import UIKit

protocol CardSelectorViewControllerDelegate: AnyObject {
    func cardSelectorViewController(_ controller: CardSelectorViewController, didSelectCard card: PaymentCard)
    func cardSelectorViewControllerDidSelectAddNewCard(_ controller: CardSelectorViewController)
}

final class CardSelectorViewController: UIViewController {
    
    @IBOutlet weak var titleView: PopupTitleView!
    @IBOutlet weak var tableView: UITableView!
    
    weak var delegate: CardSelectorViewControllerDelegate?
    
    private var cards: [PaymentCard]
    
    init(cards: [PaymentCard]) {
        self.cards = cards
        let nib = R.nib.cardSelectorView
        super.init(nibName: nib.name, bundle: nib.bundle)
        transitioningDelegate = PopupPresentationManager.shared
        modalPresentationStyle = .custom
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.cornerRadius = 13
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.layer.masksToBounds = true
        titleView.titleLabel.text = R.string.localizable.select_a_card()
        titleView.closeButton.addTarget(self, action: #selector(close), for: .touchUpInside)
        tableView.rowHeight = 75
        tableView.register(R.nib.paymentCardCell)
        tableView.dataSource = self
        tableView.delegate = self
        preferredContentSize.height = 364
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.isScrollEnabled = tableView.contentSize.height > tableView.frame.height
    }
    
    @objc func close(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
    private func removeCard(at indexPath: IndexPath, completion: @escaping (Bool) -> Void) {
        let hud = Hud()
        hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
        let card = cards[indexPath.row]
        RouteAPI.deleteInstrument(with: card.instrumentID) { result in
            switch result {
            case .success, .failure(.notFound), .failure(.emptyResponse):
                self.cards.remove(at: indexPath.row)
                self.tableView.deleteRows(at: [indexPath], with: .automatic)
                PaymentCard.remove(card)
                hud.hide()
                completion(true)
            case .failure(let error):
                hud.set(style: .error, text: error.localizedDescription)
                hud.scheduleAutoHidden()
                completion(false)
            }
        }
    }
    
}

extension CardSelectorViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        cards.count + 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.payment_card, for: indexPath)!
        if indexPath.row < cards.count {
            let card = cards[indexPath.row]
            cell.schemeImageView.image = card.schemeImage
            cell.titleLabel.text = card.scheme.capitalized + " .... " + card.postfix
        } else {
            cell.schemeImageView.image = R.image.wallet.add_card()
            cell.titleLabel.text = R.string.localizable.add_credit_or_debit_card()
        }
        return cell
    }
    
}

extension CardSelectorViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.row < cards.count {
            let card = cards[indexPath.row]
            delegate?.cardSelectorViewController(self, didSelectCard: card)
        } else {
            delegate?.cardSelectorViewControllerDidSelectAddNewCard(self)
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.row < cards.count else {
            return nil
        }
        let delete = UIContextualAction(style: .destructive, title: R.string.localizable.delete()) { _, _, completion in
            let card = self.cards[indexPath.row]
            let confirmation = UIAlertController(title: R.string.localizable.delete_card(), message: card.scheme.capitalized + " .... " + card.postfix, preferredStyle: .alert)
            confirmation.addAction(UIAlertAction(title: R.string.localizable.delete(), style: .destructive, handler: { _ in
                self.removeCard(at: indexPath, completion: completion)
            }))
            confirmation.addAction(UIAlertAction(title: R.string.localizable.cancel(), style: .cancel, handler: { _ in
                completion(false)
            }))
            self.present(confirmation, animated: true)
        }
        return UISwipeActionsConfiguration(actions: [delete])
    }
    
}
