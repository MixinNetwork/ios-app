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
    var textContentType: UITextContentType = .oneTimeCode
    
    // UITextInput
    var selectedTextRange: UITextRange?
    var markedTextStyle: [NSAttributedString.Key : Any]?
    var inputDelegate: UITextInputDelegate?
    lazy var internalTokenizer = UITextInputStringTokenizer()
    
    @IBInspectable
    var spacing: CGFloat = 25 {
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
    var digitWidth: CGFloat = 15 {
        didSet {
            setNeedsLayout()
        }
    }
    
    @IBInspectable
    var indicatorUnhighlightedColor: UIColor = R.color.line()! {
        didSet {
            updateCursor()
        }
    }
    
    @IBInspectable
    var indicatorHighlightedColor: UIColor = UIColor(rgbValue: 0x397EE4) {
        didSet {
            updateCursor()
        }
    }
    
    @IBInspectable
    var indicatorErrorColor: UIColor = .error
    
    var text: String {
        get {
            return digits.joined()
        }
        set {
            if let value = Int(newValue.prefix(numberOfDigits)) {
                digits = String(value).compactMap(String.init)
            } else {
                digits = []
            }
            updateCursor()
        }
    }
    
    var receivesInput = true
    
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
        let contentWidth = digitWidth * CGFloat(numberOfDigits) + spacing * CGFloat(numberOfDigits - 1)
        let leftMargin = (bounds.width - contentWidth) / 2
        for i in 0..<numberOfDigits {
            let x = (digitWidth + spacing) * CGFloat(i) + leftMargin
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
    
}

extension VerificationCodeField: UIKeyInput {
    
    var hasText: Bool {
        return !text.isEmpty
    }
    
    func insertText(_ text: String) {
        guard receivesInput else {
            return
        }
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
        guard receivesInput else {
            return
        }
        guard digits.count > 0 else {
            return
        }
        digits = Array(digits.dropLast())
        updateCursor()
    }
    
}

extension VerificationCodeField: UITextInput {
    
    func text(in range: UITextRange) -> String? {
        guard let range = range as? TextRange else {
            return nil
        }
        return String(text[range.start.value...range.end.value])
    }
    
    func replace(_ range: UITextRange, withText text: String) {
        guard receivesInput else {
            return
        }
        guard let range = range as? TextRange else {
            return
        }
        self.text.replaceSubrange(range.start.value...range.end.value, with: text)
    }
    
    var markedTextRange: UITextRange? {
        return nil
    }
    
    func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
        
    }
    
    func unmarkText() {
        
    }
    
    var beginningOfDocument: UITextPosition {
        return TextPosition(value: text.startIndex)
    }
    
    var endOfDocument: UITextPosition {
        return TextPosition(value: text.endIndex)
    }
    
    func textRange(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> UITextRange? {
        guard let from = fromPosition as? TextPosition, let to = toPosition as? TextPosition else {
            return nil
        }
        return TextRange(start: from, end: to)
    }
    
    func position(from position: UITextPosition, offset: Int) -> UITextPosition? {
        guard let position = position as? TextPosition else {
            return nil
        }
        let advancedPosition = text.index(position.value, offsetBy: offset)
        return TextPosition(value: advancedPosition)
    }
    
    func position(from position: UITextPosition, in direction: UITextLayoutDirection, offset: Int) -> UITextPosition? {
        switch direction {
        case .left:
            return self.position(from: position, offset: -offset)
        case .right:
            return self.position(from: position, offset: offset)
        case .up, .down:
            return position
        @unknown default:
            return nil
        }
    }
    
    func compare(_ position: UITextPosition, to other: UITextPosition) -> ComparisonResult {
        guard let position = position as? TextPosition, let other = other as? TextPosition else {
            return .orderedSame
        }
        if position.value > other.value {
            return .orderedAscending
        } else if position.value < other.value {
            return .orderedDescending
        } else {
            return .orderedSame
        }
    }
    
    func offset(from: UITextPosition, to toPosition: UITextPosition) -> Int {
        guard let from = from as? TextPosition, let to = toPosition as? TextPosition else {
            return 0
        }
        return text.distance(from: from.value, to: to.value)
    }
    
    var tokenizer: UITextInputTokenizer {
        return internalTokenizer
    }
    
    func position(within range: UITextRange, farthestIn direction: UITextLayoutDirection) -> UITextPosition? {
        guard let range = range as? TextRange, let str = self.text(in: range) else {
            return nil
        }
        switch direction {
        case .right, .down:
            return TextPosition(value: str.endIndex)
        case .left, .up:
            return TextPosition(value: str.startIndex)
        @unknown default:
            return nil
        }
    }
    
    func characterRange(byExtending position: UITextPosition, in direction: UITextLayoutDirection) -> UITextRange? {
        guard let position = position as? TextPosition else {
            return nil
        }
        switch direction {
        case .right:
            return TextRange(start: position, end: TextPosition(value: text.endIndex))
        case .left:
            return TextRange(start: TextPosition(value: text.startIndex), end: position)
        case .up, .down:
            return TextRange(start: position, end: position)
        @unknown default:
            return nil
        }
    }
    
    func baseWritingDirection(for position: UITextPosition, in direction: UITextStorageDirection) -> UITextWritingDirection {
        return .natural
    }
    
    func setBaseWritingDirection(_ writingDirection: UITextWritingDirection, for range: UITextRange) {
        
    }
    
    func firstRect(for range: UITextRange) -> CGRect {
        return .zero
    }
    
    func caretRect(for position: UITextPosition) -> CGRect {
        return .zero
    }
    
    func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        return []
    }
    
    func closestPosition(to point: CGPoint) -> UITextPosition? {
        return nil
    }
    
    func closestPosition(to point: CGPoint, within range: UITextRange) -> UITextPosition? {
        return nil
    }
    
    func characterRange(at point: CGPoint) -> UITextRange? {
        return nil
    }
    
}

extension VerificationCodeField {
    
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
    
    class TextPosition: UITextPosition {
        
        let value: String.Index
        
        init(value: String.Index) {
            self.value = value
        }
        
    }
    
    class TextRange: UITextRange {
        
        private let internalStart: TextPosition
        private let internalEnd: TextPosition
        
        override var isEmpty: Bool {
            return true
        }
        
        override var start: TextPosition {
            return internalStart
        }
        
        override var end: TextPosition {
            return internalEnd
        }
        
        init(start: TextPosition, end: TextPosition) {
            self.internalStart = start
            self.internalEnd = end
        }
        
    }
    
}
