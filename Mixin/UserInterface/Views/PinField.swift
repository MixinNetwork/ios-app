import UIKit

protocol PinFieldDelegate: AnyObject {
    func inputFinished(pin: String)
}

class PinField: UIControl, UITextInputTraits {
    
    var filledLayers = [CALayer]()
    var emptyLayers = [CALayer]()
    
    var autocapitalizationType: UITextAutocapitalizationType = .none
    var autocorrectionType: UITextAutocorrectionType = .no
    var spellCheckingType: UITextSpellCheckingType = .no
    var keyboardAppearance: UIKeyboardAppearance = .default
    var returnKeyType: UIReturnKeyType = .default
    var enablesReturnKeyAutomatically: Bool = true

    weak var delegate: PinFieldDelegate?

    @IBInspectable
    var numberOfDigits: Int = 6 {
        didSet {
            setupSubviews()
            setNeedsLayout()
        }
    }
    
    @IBInspectable
    var cellLength: CGFloat = 10 {
        didSet {
            setupSubviews()
            setNeedsLayout()
            layoutIfNeeded()
        }
    }

    var text: String {
        return digits.joined()
    }
    
    var receivesInput = true {
        didSet {
            numberPadView.target = receivesInput ? self : nil
        }
    }
    
    override var inputView: UIView? {
        return numberPadView
    }
    
    override var tintColor: UIColor! {
        didSet {
            setupSubviews()
            setNeedsLayout()
        }
    }
    
    private var digits: [String] = [] {
        didSet {
            updateCursor()
            sendActions(for: .editingChanged)
            let pin = text
            if pin.count == numberOfDigits {
                delegate?.inputFinished(pin: pin)
            }
        }
    }
    
    private var tapRecognizer: UITapGestureRecognizer!

    private lazy var numberPadView: NumberPadView = {
        let numberPad = NumberPadView()
        numberPad.target = self
        return numberPad
    }()

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
        let spacing = (bounds.width - CGFloat(numberOfDigits) * cellLength) / CGFloat(numberOfDigits - 1)
        let y = (bounds.height - cellLength) / 2
        for i in 0..<numberOfDigits {
            let x = (cellLength + spacing) * CGFloat(i)
            let frame = CGRect(x: x, y: y, width: cellLength, height: cellLength)
            filledLayers[i].frame = frame
            emptyLayers[i].frame = frame
        }
    }
    
    func clear() {
        guard !digits.isEmpty else {
            return
        }
        digits = []
    }
    
    @objc private func tap(recognizer: UITapGestureRecognizer) {
        becomeFirstResponder()
    }

    private func updateCursor() {
        let position = min(digits.count, numberOfDigits)
        for i in 0..<position {
            filledLayers[i].opacity = 1
            emptyLayers[i].opacity = 0
        }
        for i in position..<numberOfDigits {
            filledLayers[i].opacity = 0
            emptyLayers[i].opacity = 1
        }
    }

    private func prepare() {
        setupSubviews()
        tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tap(recognizer:)))
        addGestureRecognizer(tapRecognizer)
    }
    
    private func setupSubviews() {
        if !filledLayers.isEmpty {
            filledLayers.forEach {
                $0.removeFromSuperlayer()
            }
        }
        if !emptyLayers.isEmpty {
            emptyLayers.forEach {
                $0.removeFromSuperlayer()
            }
        }
        var filled = [CALayer]()
        var empty = [CALayer]()
        for _ in 0..<numberOfDigits {
            let ring = CAShapeLayer()
            let rect = CGRect(x: 0, y: 0, width: cellLength, height: cellLength)
            ring.path = CGPath(ellipseIn: rect, transform: nil)
            ring.strokeColor = tintColor.cgColor
            ring.fillColor = UIColor.clear.cgColor
            ring.lineWidth = 1
            empty.append(ring)
            let dot = CALayer()
            dot.cornerRadius = cellLength / 2
            dot.masksToBounds = true
            dot.backgroundColor = tintColor.cgColor
            filled.append(dot)
        }
        filled.forEach{ layer.addSublayer($0) }
        empty.forEach{ layer.addSublayer($0) }
        filledLayers = filled
        emptyLayers = empty
        updateCursor()
    }
    
}

extension PinField: UIKeyInput {
    
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
    }
    
    func deleteBackward() {
        guard digits.count > 0 else {
            return
        }
        digits = Array(digits.dropLast())
    }
    
}
