import UIKit
import PassKit
import Frames
import MixinServices

final class PaymentSourceViewController: UIViewController {
    
    let tableView = UITableView(frame: .zero, style: .insetGrouped)
    
    var synchronizeCardsBeforePresentingSelector = true
    
    private let order: BuyCryptoOrder
    private let isApplePayAvailable: Bool
    
    private weak var framesViewController: UIViewController?
    
    init(order: BuyCryptoOrder, payments: Set<RouteProfile.Payment>) {
        self.order = order
        self.isApplePayAvailable = payments.contains(.applePay)
            && PKPaymentAuthorizationController.canMakePayments(usingNetworks: BuyCryptoConfig.applePayNetworks)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .background
        tableView.backgroundColor = .background
        tableView.separatorStyle = .none
        view.addSubview(tableView)
        tableView.snp.makeEdgesEqualToSuperview()
        tableView.register(R.nib.paymentSourceCell)
        tableView.rowHeight = 64
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.reloadData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: true)
    }
    
    private func addNewCard() {
        let config = PaymentFormConfiguration(apiKey: MixinKeys.frames,
                                              environment: BuyCryptoConfig.framesEnvironment,
                                              supportedSchemes: BuyCryptoConfig.framesSchemes,
                                              billingFormData: nil)
        let style = PaymentStyle(paymentFormStyle: NoBillingPaymentFormStyle(),
                                 billingFormStyle: DefaultBillingFormStyle())
        let frames = PaymentFormFactory.buildViewController(configuration: config, style: style) { result in
            switch result {
            case .success(let detail):
                let hud = Queue.main.autoSync {
                    let hud = Hud()
                    hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
                    return hud
                }
                RouteAPI.createInstrument(with: detail.token) { result in
                    switch result {
                    case .success(let card):
                        hud.hide()
                        PaymentCard.save(card)
                        self.previewCardOrder(with: card)
                    case .failure(let error):
                        hud.set(style: .error, text: error.localizedDescription)
                        hud.scheduleAutoHidden()
                    }
                }
            case .failure(.userCancelled):
                break
            case .failure(let error):
                DispatchQueue.main.async {
                    showAutoHiddenHud(style: .error, text: error.localizedDescription)
                }
                Logger.general.error(category: "PaymentSelector", message: error.localizedDescription)
            }
        }
        frames.title = R.string.localizable.add_card()
        frames.navigationItem.standardAppearance = HomeNavigationController.navigationBarAppearance()
        navigationController?.pushViewController(frames, animated: true)
        framesViewController = frames
    }
    
    private func presentCardSelector() {
        let cards = PaymentCard.cards() ?? []
        if cards.isEmpty {
            addNewCard()
        } else {
            let selector = CardSelectorViewController(cards: cards)
            selector.delegate = self
            present(selector, animated: true)
        }
    }
    
    private func previewCardOrder(with card: PaymentCard) {
        guard let navigationController else {
            return
        }
        var viewControllers = navigationController.viewControllers
        if let framesViewController, viewControllers.last == framesViewController {
            viewControllers.removeLast()
        }
        let preview = BuyingOrderPreviewViewController(order: order, payment: .card(card))
        let container = ContainerViewController.instance(viewController: preview, title: R.string.localizable.order_confirm())
        viewControllers.append(container)
        navigationController.setViewControllers(viewControllers, animated: true)
    }
    
}

extension PaymentSourceViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.payment_source, for: indexPath)!
        switch indexPath.section {
        case 0:
            if isApplePayAvailable {
                cell.schemeImageView.image = R.image.wallet.apple_pay()
                cell.nameLabel.text = "Apple Pay"
            } else {
                fallthrough
            }
        case 1:
            cell.schemeImageView.image = R.image.wallet.card()
            cell.nameLabel.text = R.string.localizable.debit_or_credit_card()
        default:
            break
        }
        return cell
    }
    
}

extension PaymentSourceViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        1
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        isApplePayAvailable ? 2 : 1
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section == 0 ? 20 : 10
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        nil
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch indexPath.section {
        case 0:
            if isApplePayAvailable {
                let preview = BuyingOrderPreviewViewController(order: order, payment: .applePay)
                let container = ContainerViewController.instance(viewController: preview, title: R.string.localizable.order_confirm())
                self.navigationController?.pushViewController(container, animated: true)
            } else {
                fallthrough
            }
        case 1:
            if !synchronizeCardsBeforePresentingSelector {
                presentCardSelector()
            } else {
                let hud = Hud()
                hud.show(style: .busy, text: "", on: AppDelegate.current.mainWindow)
                _ = RouteAPI.instruments { result in
                    switch result {
                    case .success(let cards):
                        PaymentCard.replace(cards)
                        hud.hide()
                        self.presentCardSelector()
                    case .failure(let error):
                        hud.set(style: .error, text: error.localizedDescription)
                        hud.scheduleAutoHidden()
                        Logger.general.error(category: "BuyingAmount", message: "Failed to load cards: \(error)")
                    }
                }
            }
        default:
            break
        }
    }
    
}

extension PaymentSourceViewController: CardSelectorViewControllerDelegate {
    
    func cardSelectorViewController(_ controller: CardSelectorViewController, didSelectCard card: PaymentCard) {
        dismiss(animated: true) {
            self.previewCardOrder(with: card)
        }
    }
    
    func cardSelectorViewControllerDidSelectAddNewCard(_ controller: CardSelectorViewController) {
        dismiss(animated: true) {
            self.addNewCard()
        }
    }
    
}

fileprivate enum PaymentColor {
    static let mainFontColor: UIColor = .text
    static let secondaryFontColor: UIColor = R.color.text_desc()!
    static let errorColor: UIColor = .mixinRed
    static let backgroundColor: UIColor = .background
    static let textFieldBackgroundColor: UIColor = R.color.background_input()!
    static let borderRadius: CGFloat = 8
    static let borderWidth: CGFloat = 0
}

struct NoBillingPaymentFormStyle: PaymentFormStyle {
    var backgroundColor: UIColor = PaymentColor.backgroundColor
    var headerView: PaymentHeaderCellStyle = StyleOrganiser.PaymentHeaderViewStyle()
    var addBillingSummary: CellButtonStyle? = nil
    var editBillingSummary: BillingSummaryViewStyle? = nil
    var cardholderInput: CellTextFieldStyle? = StyleOrganiser.CardholderNameSection()
    var cardNumber: CellTextFieldStyle = StyleOrganiser.CardNumberSection()
    var expiryDate: CellTextFieldStyle = StyleOrganiser.ExpiryDateSection()
    var securityCode: CellTextFieldStyle? = StyleOrganiser.SecurityNumberSection()
    var payButton: ElementButtonStyle = StyleOrganiser.PayButtonStyle()
}

private enum StyleOrganiser {
    
    struct PaymentHeaderViewStyle: PaymentHeaderCellStyle {
        var shouldHideAcceptedCardsList = true
        var backgroundColor: UIColor = PaymentColor.backgroundColor
        var headerLabel: ElementStyle? = PaymentHeaderLabel()
        var subtitleLabel: ElementStyle? = PaymentHeaderSubtitle()
        var schemeIcons: [UIImage?] = []
    }
    
    struct PayButtonStyle: ElementButtonStyle {
        var image: UIImage?
        var textAlignment: NSTextAlignment = .center
        var text: String = R.string.localizable.add_card()
        var font = UIFont.systemFont(ofSize: 15)
        var disabledTextColor: UIColor = R.color.button_text_disabled()!
        var disabledTintColor: UIColor = R.color.icon_tint_disabled()!
        var activeTintColor: UIColor = PaymentColor.mainFontColor
        var backgroundColor: UIColor = R.color.theme()!
        var textColor: UIColor = .white
        var normalBorderColor: UIColor = .clear
        var focusBorderColor: UIColor = .clear
        var errorBorderColor: UIColor = .clear
        var imageTintColor: UIColor = .clear
        var isHidden = false
        var isEnabled = true
        var height: Double = 56
        var width: Double = 0
        var cornerRadius: CGFloat = 10
        var borderWidth: CGFloat = 0
        var textLeading: CGFloat = 0
    }
    
    struct CancelButtonStyle: ElementButtonStyle {
        var textAlignment: NSTextAlignment = .natural
        var isEnabled = true
        var disabledTextColor: UIColor = PaymentColor.secondaryFontColor
        var disabledTintColor: UIColor = .clear
        var activeTintColor: UIColor = .clear
        var imageTintColor: UIColor = .clear
        var normalBorderColor: UIColor = .clear
        var focusBorderColor: UIColor = .clear
        var errorBorderColor: UIColor = .clear
        var image: UIImage?
        var textLeading: CGFloat = 0
        var cornerRadius: CGFloat = PaymentColor.borderRadius
        var borderWidth: CGFloat = PaymentColor.borderWidth
        var height: Double = 60
        var width: Double = 70
        var isHidden = false
        var text: String = R.string.localizable.cancel()
        var font: UIFont = .systemFont(ofSize: 17, weight: .semibold)
        var backgroundColor: UIColor = .clear
        var textColor: UIColor = PaymentColor.mainFontColor
    }
    
    struct DoneButtonStyle: ElementButtonStyle {
        var textAlignment: NSTextAlignment = .natural
        var isEnabled = true
        var disabledTextColor: UIColor = PaymentColor.secondaryFontColor
        var disabledTintColor: UIColor = .clear
        var activeTintColor: UIColor = .clear
        var imageTintColor: UIColor = .clear
        var normalBorderColor: UIColor = .clear
        var focusBorderColor: UIColor = .clear
        var errorBorderColor: UIColor = .clear
        var image: UIImage?
        var textLeading: CGFloat = 0
        var cornerRadius: CGFloat = PaymentColor.borderRadius
        var borderWidth: CGFloat = PaymentColor.borderWidth
        var height: Double = 60
        var width: Double = 70
        var isHidden = false
        var text: String = R.string.localizable.done()
        var font: UIFont = .systemFont(ofSize: 17, weight: .semibold)
        var backgroundColor: UIColor = .clear
        var textColor: UIColor = PaymentColor.mainFontColor
    }
    
    struct PaymentHeaderLabel: ElementStyle {
        var textAlignment: NSTextAlignment = .natural
        var isHidden = false
        var text: String = R.string.localizable.add_card()
        var font: UIFont = .systemFont(ofSize: 24)
        var backgroundColor: UIColor = .clear
        var textColor: UIColor = PaymentColor.mainFontColor
    }
    
    struct PaymentHeaderSubtitle: ElementStyle {
        var textAlignment: NSTextAlignment = .natural
        var isHidden = false
        var text: String = R.string.localizable.accepted_cards(BuyCryptoConfig.supportedCards)
        var font: UIFont = .systemFont(ofSize: 12)
        var backgroundColor: UIColor = .clear
        var textColor: UIColor = PaymentColor.mainFontColor
    }
    
    struct CardholderNameSection: CellTextFieldStyle {
        var isMandatory = false
        var backgroundColor: UIColor = .clear
        var textfield: ElementTextFieldStyle = TextFieldStyle(isSupportingNumericKeyboard: false)
        var title: ElementStyle? = TitleStyle(text: R.string.localizable.cardholder_name())
        var mandatory: ElementStyle? = MandatoryStyle(text: "")
        var hint: ElementStyle?
        var error: ElementErrorViewStyle?
    }
    
    struct CardNumberSection: CellTextFieldStyle {
        var isMandatory = true
        var backgroundColor: UIColor = .clear
        var textfield: ElementTextFieldStyle = TextFieldStyle()
        var title: ElementStyle? = TitleStyle(text: R.string.localizable.card_number())
        var mandatory: ElementStyle? = MandatoryStyle(text: "")
        var hint: ElementStyle?
        var error: ElementErrorViewStyle? = ErrorViewStyle(text: R.string.localizable.card_number_error())
    }
    
    struct ExpiryDateSection: CellTextFieldStyle {
        var textfield: ElementTextFieldStyle = TextFieldStyle(placeholder: "_ _ / _ _")
        var isMandatory = true
        var backgroundColor: UIColor = .clear
        var title: ElementStyle? = TitleStyle(text: R.string.localizable.expiry_date())
        var mandatory: ElementStyle? = MandatoryStyle(text: "")
        var hint: ElementStyle?
        var error: ElementErrorViewStyle? = ErrorViewStyle(text: R.string.localizable.expiry_date_error())
    }
    
    struct SecurityNumberSection: CellTextFieldStyle {
        var textfield: ElementTextFieldStyle = TextFieldStyle()
        var isMandatory = true
        var backgroundColor: UIColor = .clear
        var title: ElementStyle? = TitleStyle(text: R.string.localizable.security_code())
        var mandatory: ElementStyle? = MandatoryStyle(text: "")
        var hint: ElementStyle?
        var error: ElementErrorViewStyle? = ErrorViewStyle(text: R.string.localizable.security_code_error())
    }
    
    struct TextFieldStyle: ElementTextFieldStyle {
        var textAlignment: NSTextAlignment = .natural
        var text: String = ""
        var isSupportingNumericKeyboard = true
        var height: Double = 56
        var cornerRadius: CGFloat = PaymentColor.borderRadius
        var borderWidth: CGFloat = PaymentColor.borderWidth
        var placeholder: String?
        var tintColor: UIColor = PaymentColor.mainFontColor
        var normalBorderColor: UIColor = .clear
        var focusBorderColor: UIColor = .clear
        var errorBorderColor: UIColor = PaymentColor.errorColor
        var isHidden = false
        var font: UIFont = .systemFont(ofSize: 15)
        var backgroundColor: UIColor = PaymentColor.textFieldBackgroundColor
        var textColor: UIColor = PaymentColor.mainFontColor
    }
    
    struct TitleStyle: ElementStyle {
        var textAlignment: NSTextAlignment = .natural
        var text: String
        var isHidden = false
        var font: UIFont = .systemFont(ofSize: 15)
        var backgroundColor: UIColor = .clear
        var textColor: UIColor = PaymentColor.mainFontColor
    }
    
    struct MandatoryStyle: ElementStyle {
        var textAlignment: NSTextAlignment = .natural
        var text: String
        var isHidden = false
        var font: UIFont = .systemFont(ofSize: 13)
        var backgroundColor: UIColor = .clear
        var textColor: UIColor = PaymentColor.secondaryFontColor
    }
    
    struct SubtitleElementStyle: ElementStyle {
        var textAlignment: NSTextAlignment = .natural
        var text: String
        var textColor: UIColor = PaymentColor.secondaryFontColor
        var backgroundColor: UIColor = .clear
        var tintColor: UIColor = PaymentColor.mainFontColor
        var image: UIImage?
        var height: Double = 30
        var isHidden = false
        var font: UIFont = .systemFont(ofSize: 13)
    }
    
    struct ErrorViewStyle: ElementErrorViewStyle {
        var textAlignment: NSTextAlignment = .natural
        var text: String
        var textColor: UIColor = PaymentColor.errorColor
        var backgroundColor: UIColor = .clear
        var tintColor: UIColor = PaymentColor.errorColor
        var image: UIImage?
        var height: Double = 30
        var isHidden = true
        var font: UIFont = .systemFont(ofSize: 13)
    }
    
}
