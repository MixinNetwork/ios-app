import UIKit

final class LeverageMultiplierInputViewController: UIViewController {
    
    @IBOutlet weak var titleView: PopupTitleView!
    @IBOutlet weak var multiplierInputView: UIView!
    @IBOutlet weak var decreaseMultiplierButton: UIButton!
    @IBOutlet weak var increaseMultiplierButton: UIButton!
    @IBOutlet weak var valueLabel: UILabel!
    @IBOutlet weak var slider: UISlider!
    @IBOutlet weak var markingStackView: UIStackView!
    @IBOutlet weak var simulationStackView: UIStackView!
    @IBOutlet weak var profitSimulationLabel: UILabel!
    @IBOutlet weak var liquidationSimulationLabel: UILabel!
    
    var onInput: ((Decimal) -> Void)?
    
    private let side: PerpetualOrderSide
    private let maxMultiplier: Decimal
    private let marginAmount: Decimal
    
    private var multiplier: Decimal
    
    init(
        side: PerpetualOrderSide,
        maxMultiplier: Decimal,
        marginAmount: Decimal,
        currentMultiplier: Decimal,
    ) {
        self.side = side
        self.maxMultiplier = maxMultiplier
        self.marginAmount = marginAmount
        self.multiplier = min(maxMultiplier, max(1, currentMultiplier))
        let nib = R.nib.leverageMultiplierInputView
        super.init(nibName: nib.name, bundle: nib.bundle)
        modalPresentationStyle = .custom
        transitioningDelegate = BackgroundDismissablePopupPresentationManager.shared
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.layer.cornerRadius = 13
        view.layer.masksToBounds = true
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        titleView.titleLabel.text = R.string.localizable.leverage()
        titleView.closeButton.isHidden = true
        multiplierInputView.layer.cornerRadius = 8
        multiplierInputView.layer.masksToBounds = true
        
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 48, weight: .semibold)
        let maxMultiplierNumber = maxMultiplier as NSDecimalNumber
        slider.minimumValue = 1
        slider.maximumValue = maxMultiplierNumber.floatValue
        slider.value = (multiplier as NSDecimalNumber).floatValue
        
        let markings: [String]
        if maxMultiplier <= 1 {
            markings = []
        } else if maxMultiplier <= 7 {
            markings = (1...maxMultiplierNumber.intValue).map { multiplier in
                PerpetualLeverage.stringRepresentation(multiplier: multiplier)
            }
        } else {
            let count = 5
            let scale = maxMultiplierNumber.intValue / (count - 1)
            var list = [PerpetualLeverage.stringRepresentation(multiplier: 1)]
            for i in 1..<count - 1 {
                list.append(PerpetualLeverage.stringRepresentation(multiplier: scale * i))
            }
            list.append(PerpetualLeverage.stringRepresentation(multiplier: maxMultiplier))
            markings = list
        }
        for marking in markings {
            let label = UILabel()
            label.font = .systemFont(ofSize: 12, weight: .medium)
            label.textColor = R.color.text()
            label.textAlignment = .center
            label.text = marking
            markingStackView.addArrangedSubview(label)
        }
        
        for label: UILabel in [profitSimulationLabel, liquidationSimulationLabel] {
            label.font = UIFontMetrics.default.scaledFont(
                for: .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            )
        }
        updateViews(multiplier: multiplier)
        
        let actionView = R.nib.authenticationPreviewDoubleButtonTrayView(withOwner: nil)!
        actionView.backgroundColor = R.color.background_secondary()
        view.addSubview(actionView)
        actionView.snp.makeConstraints { make in
            make.top.equalTo(simulationStackView.snp.bottom)
            make.leading.trailing.bottom.equalTo(view.safeAreaLayoutGuide)
        }
        actionView.leftButton.setTitle(R.string.localizable.cancel(), for: .normal)
        actionView.leftButton.addTarget(self, action: #selector(cancelInput(_:)), for: .touchUpInside)
        actionView.rightButton.setTitle(R.string.localizable.apply(), for: .normal)
        actionView.rightButton.addTarget(self, action: #selector(applyLeverage(_:)), for: .touchUpInside)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updatePreferredContentSizeHeight()
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updatePreferredContentSizeHeight()
    }
    
    @IBAction func decreaseMultiplierBy1(_ sender: Any) {
        multiplier = max(1, multiplier - 1)
        slider.value = NSDecimalNumber(decimal: multiplier).floatValue
        updateViews(multiplier: multiplier)
    }
    
    @IBAction func decreaseMultiplierBy5(_ sender: UILongPressGestureRecognizer) {
        switch sender.state {
        case .began:
            multiplier = max(1, multiplier - 5)
            slider.value = NSDecimalNumber(decimal: multiplier).floatValue
            updateViews(multiplier: multiplier)
        default:
            break
        }
    }
    
    @IBAction func increaseMultiplierBy1(_ sender: Any) {
        multiplier = min(maxMultiplier, multiplier + 1)
        slider.value = NSDecimalNumber(decimal: multiplier).floatValue
        updateViews(multiplier: multiplier)
    }
    
    @IBAction func increaseMultiplierBy5(_ sender: UILongPressGestureRecognizer) {
        switch sender.state {
        case .began:
            multiplier = min(maxMultiplier, multiplier + 5)
            slider.value = NSDecimalNumber(decimal: multiplier).floatValue
            updateViews(multiplier: multiplier)
        default:
            break
        }
    }
    
    @IBAction func sliderValueChanged(_ sender: UISlider) {
        multiplier = Decimal(round(Double(sender.value)))
        updateViews(multiplier: multiplier)
    }
    
    @objc private func cancelInput(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
    }
    
    @objc private func applyLeverage(_ sender: Any) {
        presentingViewController?.dismiss(animated: true)
        onInput?(multiplier)
    }
    
    private func updatePreferredContentSizeHeight() {
        view.layoutIfNeeded()
        let fittingSize = CGSize(
            width: view.bounds.width,
            height: UIView.layoutFittingExpandedSize.height
        )
        preferredContentSize.height = view.systemLayoutSizeFitting(fittingSize).height
    }
    
    private func updateViews(multiplier: Decimal) {
        decreaseMultiplierButton.isEnabled = multiplier > 1
        increaseMultiplierButton.isEnabled = multiplier < maxMultiplier
        valueLabel.text = PerpetualLeverage.stringRepresentation(multiplier: multiplier)
        profitSimulationLabel.text = PerpetualChangeSimulation.profit(
            side: side,
            margin: marginAmount,
            leverageMultiplier: multiplier,
            priceChangePercent: 0.01
        )
        liquidationSimulationLabel.text = PerpetualChangeSimulation.liquidation(
            side: side,
            margin: marginAmount,
            leverageMultiplier: multiplier
        )
    }
    
}
