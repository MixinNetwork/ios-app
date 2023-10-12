import UIKit

final class PriceExpiredViewController: UIViewController {
    
    @IBOutlet weak var countdownLabel: UILabel!
    @IBOutlet weak var oldPriceLabel: UILabel!
    @IBOutlet weak var newPriceLabel: UILabel!
    
    private let oldOrder: BuyCryptoConfirmedOrder
    private let newOrder: BuyCryptoConfirmedOrder
    private let newPrice: Decimal
    private let newAssetAmount: Decimal
    private let onPlaceAgain: ((BuyCryptoConfirmedOrder) -> Void)
    private let onCancel: (() -> Void)
    
    init(
        order: BuyCryptoConfirmedOrder,
        newPrice: Decimal,
        newAssetAmount: Decimal,
        onPlaceAgain: @escaping ((BuyCryptoConfirmedOrder) -> Void),
        onCancel: @escaping () -> Void
    ) {
        let newTicker = order.ticker.replacing(price: newPrice, assetAmount: newAssetAmount)
        let newOrder = BuyCryptoConfirmedOrder(confirmedTicker: newTicker, order: order)
        
        self.oldOrder = order
        self.newOrder = newOrder
        self.newPrice = newPrice
        self.newAssetAmount = newAssetAmount
        self.onPlaceAgain = onPlaceAgain
        self.onCancel = onCancel
        
        let nib = R.nib.priceExpiredView
        super.init(nibName: nib.name, bundle: nib.bundle)
        modalPresentationStyle = .custom
        transitioningDelegate = PopupPresentationManager.shared
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.cornerRadius = 13
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.layer.masksToBounds = true
        countdownLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        oldPriceLabel.text = oldOrder.priceString
        newPriceLabel.text = newOrder.priceString
        preferredContentSize.height = 508
    }
    
    @IBAction func useNewPrice(_ sender: Any) {
        onPlaceAgain(newOrder)
    }
    
    @IBAction func cancelOrder(_ sender: Any) {
        onCancel()
    }
    
}
