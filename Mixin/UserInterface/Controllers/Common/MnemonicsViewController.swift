import UIKit

protocol MnemonicsViewController: UIViewController {
    
    var inputStackView: UIStackView! { get }
    var inputFields: [MnemonicsInputField] { get set }
    
}

extension MnemonicsViewController {
    
    var textFieldPhrases: [String] {
        inputFields.map { inputField in
            guard let text = inputField.textField.text else {
                return ""
            }
            return text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
    }
    
    func addRowStackViewForButtonsIntoInputStackView() {
        let rowStackView = UIStackView()
        rowStackView.axis = .horizontal
        rowStackView.distribution = .fillEqually
        rowStackView.spacing = 10
        inputStackView.addArrangedSubview(rowStackView)
        rowStackView.snp.makeConstraints { make in
            make.height.equalTo(40)
        }
    }
    
    func addTextFields(
        backgroundColor: MnemonicsInputField.BackgroundColor,
        count: Int,
    ) {
        var rowStackView = UIStackView()
        for i in 0..<count {
            let frame = CGRect(x: 0, y: 0, width: 105, height: 40)
            let wrapper = UIView(frame: frame)
            wrapper.backgroundColor = switch backgroundColor {
            case .primary:
                R.color.background()
            case .secondary:
                R.color.background_secondary()
            }
            wrapper.layer.masksToBounds = true
            wrapper.layer.cornerRadius = 8
            wrapper.snp.makeConstraints { make in
                make.height.greaterThanOrEqualTo(40)
            }
            
            let label = UILabel()
            label.font = .systemFont(ofSize: 13, weight: .medium)
            label.text = "\(i + 1)"
            label.textAlignment = .center
            wrapper.addSubview(label)
            label.snp.makeConstraints { make in
                make.width.greaterThanOrEqualTo(15)
                make.leading.equalToSuperview().offset(8)
                make.centerY.equalToSuperview()
            }
            
            let insets = UIEdgeInsets(top: 0, left: 29, bottom: 0, right: 0)
            let textField = MnemonicTextField(frame: frame, insets: insets)
            textField.tag = i
            textField.font = .systemFont(ofSize: 13, weight: .medium)
            textField.adjustsFontSizeToFitWidth = true
            textField.minimumFontSize = 5
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            textField.spellCheckingType = .no
            wrapper.addSubview(textField)
            textField.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            
            let inputField = MnemonicsInputField(label: label, textField: textField)
            inputField.setTextColor(.normal)
            inputFields.append(inputField)
            
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
    
    func addButtonIntoInputFields(
        image: UIImage,
        title: String,
        action: Selector
    ) {
        guard let stackView = inputStackView.arrangedSubviews.last as? UIStackView else {
            return
        }
        
        let wrapper = UIView()
        wrapper.backgroundColor = .clear
        
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
