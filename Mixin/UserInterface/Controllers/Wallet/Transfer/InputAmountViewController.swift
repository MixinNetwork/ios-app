import UIKit
import MixinServices

class InputAmountViewController: UIViewController {
    
    @IBOutlet weak var amountStackView: UIStackView!
    @IBOutlet weak var amountLabel: UILabel!
    @IBOutlet weak var calculatedValueLabel: UILabel!
    @IBOutlet weak var insufficientBalanceLabel: UILabel!
    @IBOutlet weak var accessoryStackView: UIStackView!
    @IBOutlet weak var decimalSeparatorButton: HighlightableButton!
    @IBOutlet weak var deleteBackwardsButton: HighlightableButton!
    @IBOutlet weak var reviewButton: StyledButton!
    
    @IBOutlet var decimalButtons: [DecimalButton]!
    
    @IBOutlet weak var numberPadTopConstraint: NSLayoutConstraint!
    
    let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = .current
        formatter.usesGroupingSeparator = true
        formatter.positivePrefix = ""
        formatter.negativePrefix = ""
        return formatter
    }()
    
    var accumulator: DecimalAccumulator {
        didSet {
            guard isViewLoaded else {
                return
            }
            reloadViews(inputAmount: accumulator.decimal)
        }
    }
    
    private let feedback = UIImpactFeedbackGenerator(style: .light)
    
    private weak var clearInputTimer: Timer?
    
    init(accumulator: DecimalAccumulator) {
        self.accumulator = accumulator
        let nib = R.nib.inputAmountView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItem = .customerService(
            target: self,
            action: #selector(presentCustomerService(_:))
        )
        
        amountStackView.setCustomSpacing(2, after: amountLabel)
        amountLabel.font = switch ScreenHeight.current {
        case .short:
                .monospacedDigitSystemFont(ofSize: 32, weight: .regular)
        case .medium:
                .monospacedDigitSystemFont(ofSize: 48, weight: .regular)
        case .long, .extraLong:
                .monospacedDigitSystemFont(ofSize: 64, weight: .regular)
        }
        
        decimalButtons.sort(by: { $0.value < $1.value })
        decimalSeparatorButton.setTitle(Locale.current.decimalSeparator ?? ".", for: .normal)
        reloadViews(inputAmount: accumulator.decimal)
        reviewButton.style = .filled
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        feedback.prepare()
    }
    
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let key = presses.first?.key else {
            super.pressesBegan(presses, with: event)
            return
        }
        if let value = Int(key.charactersIgnoringModifiers) {
            if value >= 0 && value < decimalButtons.count {
                let button = decimalButtons[value]
                button.isHighlighted = true
            } else {
                super.pressesBegan(presses, with: event)
            }
        } else {
            switch Key(keyCode: key.keyCode) {
            case .backspace:
                deleteBackwardsButton.isHighlighted = true
            case .decimalSeparator:
                decimalSeparatorButton.isHighlighted = true
            case .enter:
                break
            default:
                super.pressesBegan(presses, with: event)
            }
        }
    }
    
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for button in decimalButtons + [decimalSeparatorButton, deleteBackwardsButton] {
            button?.isHighlighted = false
        }
        guard let key = presses.first?.key else {
            super.pressesEnded(presses, with: event)
            return
        }
        if let value = UInt8(key.charactersIgnoringModifiers) {
            if value >= 0 && value < decimalButtons.count {
                accumulator.append(value: value)
            } else {
                super.pressesEnded(presses, with: event)
            }
        } else {
            switch Key(keyCode: key.keyCode) {
            case .backspace:
                accumulator.deleteBackwards()
            case .decimalSeparator:
                accumulator.appendDecimalSeparator()
            case .enter:
                review(presses)
            default:
                super.pressesEnded(presses, with: event)
            }
        }
    }
    
    @IBAction func toggleAmountIntent(_ sender: Any) {
        
    }
    
    @IBAction func inputValue(_ sender: DecimalButton) {
        accumulator.append(value: sender.value)
    }
    
    @IBAction func inputDecimalSeparator(_ sender: Any) {
        accumulator.appendDecimalSeparator()
    }
    
    @IBAction func deleteButtonTouchDown(_ sender: Any) {
        clearInputTimer?.invalidate()
        clearInputTimer = Timer.scheduledTimer(
            withTimeInterval: 1,
            repeats: false
        ) { [weak self] _ in
            self?.replaceAmount(0)
        }
    }
    
    @IBAction func deleteButtonTouchUpInside(_ sender: Any) {
        clearInputTimer?.invalidate()
        accumulator.deleteBackwards()
    }
    
    @IBAction func deleteButtonTouchUpOutside(_ sender: Any) {
        clearInputTimer?.invalidate()
    }
    
    @IBAction func generateInputFeedback(_ sender: Any) {
        feedback.impactOccurred()
    }
    
    @IBAction func review(_ sender: Any) {
        
    }
    
    func reloadViews(inputAmount: Decimal) {
        
    }
    
    func replaceAmount(_ amount: Decimal) {
        
    }
    
    @objc private func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController()
        present(customerService, animated: true)
        reporter.report(event: .customerServiceDialog, tags: ["source": "send_amount"])
    }
    
}

extension InputAmountViewController {
    
    private enum Key {
        
        case backspace
        case decimalSeparator
        case enter
        
        init?(keyCode: UIKeyboardHIDUsage) {
            switch keyCode {
            case .keyboardDeleteOrBackspace:
                self = .backspace
            case .keyboardPeriod, .keyboardComma, .keypadPeriod:
                self = .decimalSeparator
            case .keyboardReturn, .keyboardReturnOrEnter, .keypadEnter:
                self = .enter
            default:
                return nil
            }
        }
        
    }
    
}
