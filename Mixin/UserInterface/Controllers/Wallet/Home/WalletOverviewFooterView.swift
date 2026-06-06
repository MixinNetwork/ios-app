import UIKit

final class WalletOverviewFooterView: UICollectionReusableView {
    
    static let reuseIdentifier = "wallet_overview_footer"
    
    var action: WalletOverview.ImportSecretAction? {
        didSet {
            let description = switch action {
            case .importPrivateKey:
                R.string.localizable.import_secret_description(
                    R.string.localizable.private_key()
                )
            case .importMnemonics:
                R.string.localizable.import_secret_description(
                    R.string.localizable.mnemonic_phrase()
                )
            case nil:
                ""
            }
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.preferredFont(forTextStyle: .caption1),
                .foregroundColor: R.color.text_tertiary()!,
            ]
            textView.attributedText = NSAttributedString(
                string: description,
                attributes: attributes
            )
        }
    }
    
    private weak var textView: IntroTextView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadSubviews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadSubviews()
    }
    
    private func loadSubviews() {
        let textView = IntroTextView()
        addSubview(textView)
        textView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.bottom.equalToSuperview().offset(-10)
        }
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        self.textView = textView
    }
    
}
