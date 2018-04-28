import UIKit

class VerificationCodeField: UIControl, UITextInputTraits {

    var labels = [UILabel]()
    var indicators = [UIView]()
    
    var autocapitalizationType: UITextAutocapitalizationType = .none
    var autocorrectionType: UITextAutocorrectionType = .no
    var spellCheckingType: UITextSpellCheckingType = .no
    var keyboardAppearance: UIKeyboardAppearance = .default
    var returnKeyType: UIReturnKeyType = .default
    var enablesReturnKeyAutomatically: Bool = true
    var keyboardType: UIKeyboardType = .numberPad
    
    @IBInspectable
    var spacing: CGFloat = 12 {
        didSet {
            setNeedsLayout()
        }
    }
    
    @IBInspectable
    var fontSize: CGFloat = 20 {
        didSet {
            let font = UIFont.systemFont(ofSize: fontSize)
            labels.forEach{ $0.font = font }
        }
    }
    
    @IBInspectable
    var numberOfDigits: Int = 4 {
        didSet {
            setupSubviews()
            setNeedsLayout()
        }
    }
    
    @IBInspectable
    var digitWidth: CGFloat = 32 {
        didSet {
            setNeedsLayout()
        }
    }
    
    @IBInspectable
    var indicatorUnhighlightedColor: UIColor = .lightGray {
        didSet {
            updateCursor()
        }
    }
    
    @IBInspectable
    var indicatorHighlightedColor: UIColor = .black {
        didSet {
            updateCursor()
        }
    }
    
    @IBInspectable
    var indicatorErrorColor: UIColor = .error
    
    var text: String {
        return digits.joined()
    }
    
    private var tapRecognizer: UITapGestureRecognizer!
    private var digits: [String] = [] {
        didSet {
            for i in 0..<digits.count {
                labels[i].text = digits[i]
            }
            for i in digits.count..<labels.count {
                labels[i].text = nil
            }
            sendActions(for: .editingChanged)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        prepare()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        prepare()
    }
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        for i in 0..<numberOfDigits {
            let x = (digitWidth + spacing) * CGFloat(i)
            labels[i].frame = CGRect(x: x, y: 0, width: digitWidth, height: bounds.height - 1)
            indicators[i].frame = CGRect(x: x, y: bounds.height - 1, width: digitWidth, height: 1)
        }
    }

    @objc private func tap(recognizer: UITapGestureRecognizer) {
        becomeFirstResponder()
    }
    
    func clear() {
        digits = []
        updateCursor()
    }
    
    func showError() {
        indicators.forEach {
            $0.backgroundColor = indicatorErrorColor
        }
    }
    
    private func prepare() {
        setupSubviews()
        tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tap(recognizer:)))
        addGestureRecognizer(tapRecognizer)
    }
    
    private func setupSubviews() {
        labels.forEach {
            $0.removeFromSuperview()
        }
        indicators.forEach {
            $0.removeFromSuperview()
        }
        labels = []
        indicators = []
        for _ in 0..<numberOfDigits {
            let label = UILabel()
            label.textAlignment = .center
            addSubview(label)
            labels.append(label)
            let indicator = UIView()
            addSubview(indicator)
            indicators.append(indicator)
        }
        updateCursor()
    }
    
    private func updateCursor() {
        let position = min(digits.count, indicators.count - 1)
        indicators.forEach {
            $0.backgroundColor = indicatorUnhighlightedColor
        }
        indicators[position].backgroundColor = indicatorHighlightedColor
    }
    
}

extension VerificationCodeField: UIKeyInput {
    
    var hasText: Bool {
        return !text.isEmpty
    }
    
    func insertText(_ text: String) {
        let numberOfUnfilleds = numberOfDigits - digits.count
        let newDigits = text.digits()
        let endIndexOfNewDigits = min(numberOfUnfilleds, newDigits.count)
        let digitsToAppend = Array(newDigits)[0..<endIndexOfNewDigits].map{ String($0) }
        if digitsToAppend.count > 0 {
            digits += digitsToAppend
        }
        updateCursor()
    }
    
    func deleteBackward() {
        guard digits.count > 0 else {
            return
        }
        digits = Array(digits.dropLast())
        updateCursor()
    }
    
}

