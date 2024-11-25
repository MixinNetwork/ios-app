import UIKit
import MixinServices

class MnemonicsViewController: UIViewController {
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var titleStackView: UIStackView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var inputStackView: UIStackView!
    @IBOutlet weak var footerStackView: UIStackView!
    @IBOutlet weak var confirmButton: StyledButton!
    
    @IBOutlet weak var contentViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var inputStackViewTopConstraint: NSLayoutConstraint!
    
    var textFields: [UITextField] = []
    
    var textFieldPhrases: [String] {
        textFields.map { textField in
            guard let text = textField.text else {
                return ""
            }
            return text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
    }
    
    init() {
        let nib = R.nib.mnemonicsView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        descriptionLabel.setFont(scaledFor: .monospacedDigitSystemFont(ofSize: 14, weight: .regular), adjustForContentSize: true)
        confirmButton.style = .filled
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(adjustScrollViewContentInsets(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(adjustScrollViewContentInsets(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    @IBAction func confirm(_ sender: Any) {
        
    }
    
    @objc func adjustScrollViewContentInsets(_ notification: Notification) {
        guard var endFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        endFrame = view.convert(endFrame, from: view.window)
        if notification.name == UIResponder.keyboardWillHideNotification {
            scrollView.contentInset = .zero
            contentViewHeightConstraint.priority = .defaultLow
        } else {
            scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: endFrame.height - view.safeAreaInsets.bottom, right: 0)
            contentViewHeightConstraint.constant = view.bounds.height - endFrame.height - view.safeAreaInsets.vertical
            contentViewHeightConstraint.priority = .defaultHigh
        }
        scrollView.scrollIndicatorInsets = scrollView.contentInset
        view.layoutIfNeeded()
    }
    
}

// MARK: - Input Field
extension MnemonicsViewController {
    
    func addTextFields(count: Int) {
        var rowStackView = UIStackView()
        for i in 0..<count {
            let frame = CGRect(x: 0, y: 0, width: 105, height: 40)
            let wrapper = UIView(frame: frame)
            wrapper.backgroundColor = R.color.background_quaternary()
            wrapper.layer.masksToBounds = true
            wrapper.layer.cornerRadius = 8
            wrapper.snp.makeConstraints { make in
                make.height.greaterThanOrEqualTo(40)
            }
            
            let label = UILabel()
            label.font = .systemFont(ofSize: 13, weight: .medium)
            label.textColor = R.color.text_tertiary()
            label.text = "\(i + 1)"
            label.textAlignment = .center
            wrapper.addSubview(label)
            label.snp.makeConstraints { make in
                make.width.greaterThanOrEqualTo(15)
                make.leading.equalToSuperview().offset(8)
                make.centerY.equalToSuperview()
            }
            
            let insets = UIEdgeInsets(top: 0, left: 29, bottom: 0, right: 0)
            let textField = InsetTextField(frame: frame, insets: insets)
            textField.tag = i
            textField.font = .systemFont(ofSize: 13, weight: .medium)
            textField.adjustsFontSizeToFitWidth = true
            textField.minimumFontSize = 5
            textField.autocapitalizationType = .none
            wrapper.addSubview(textField)
            textField.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            textFields.append(textField)
            
            if rowStackView.arrangedSubviews.count == 3 {
                rowStackView = UIStackView()
            }
            if rowStackView.arrangedSubviews.count == 0 {
                rowStackView.axis = .horizontal
                rowStackView.distribution = .fillEqually
                rowStackView.spacing = 10
                inputStackView.addArrangedSubview(rowStackView)
            }
            rowStackView.addArrangedSubview(wrapper)
        }
    }
    
    func addSpacerIntoInputFields() {
        guard let stackView = inputStackView.arrangedSubviews.last as? UIStackView else {
            return
        }
        let spacer = UIView()
        spacer.backgroundColor = R.color.background()
        stackView.addArrangedSubview(spacer)
    }
    
    func addButtonIntoInputFields(image: UIImage, title: String, action: Selector) {
        guard let stackView = inputStackView.arrangedSubviews.last as? UIStackView else {
            return
        }
        
        let wrapper = UIView()
        wrapper.backgroundColor = R.color.background()
        
        let imageView = UIImageView(image: image.withRenderingMode(.alwaysTemplate))
        imageView.tintColor = R.color.icon_tint()
        wrapper.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(8)
            make.centerY.equalToSuperview()
        }
        
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(R.color.text(), for: .normal)
        button.contentHorizontalAlignment = .leading
        if let label = button.titleLabel {
            label.font = .systemFont(ofSize: 12, weight: .medium)
            label.lineBreakMode = .byCharWrapping
        }
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 36, bottom: 0, right: 0)
        wrapper.addSubview(button)
        button.snp.makeEdgesEqualToSuperview()
        button.addTarget(self, action: action, for: .touchUpInside)
        
        stackView.addArrangedSubview(wrapper)
    }
    
}
