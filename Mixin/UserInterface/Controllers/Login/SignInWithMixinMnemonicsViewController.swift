import UIKit
import MixinServices

final class SignInWithMixinMnemonicsViewController: SignInWithMnemonicsViewController<MixinMnemonics.PhrasesCount> {
    
    private let analyticSource: String
    
    init(analyticSource: String) {
        self.analyticSource = analyticSource
        super.init(phrasesCount: .default)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        reporter.report(
            event: .loginStart,
            tags: [
                "type": "login_mnemonic_phrase_13",
                "source": analyticSource,
            ]
        )
    }
    
    override func reloadViews(count: MixinMnemonics.PhrasesCount) {
        super.reloadViews(count: count)
        addButtonIntoInputFields(
            image: R.image.explore.web3_send_scan()!,
            title: R.string.localizable.scan(),
            action: #selector(scanQRCode(_:))
        )
        addButtonIntoInputFields(
            image: R.image.paste()!,
            title: R.string.localizable.paste(),
            action: #selector(pastePhrases(_:))
        )
        addRowStackViewForButtonsIntoInputStackView()
        addButtonIntoInputFields(
            image: R.image.explore.web3_send_delete()!,
            title: R.string.localizable.clear(),
            action: #selector(emptyPhrases(_:))
        )
    }
    
    override func arePhrasesValid(_ phrases: [String]) -> Bool {
        MixinMnemonics.areValid(phrases: phrases)
    }
    
    override func signIn(_ sender: Any) {
        do {
            let mnemonics = try MixinMnemonics(phrases: textFieldPhrases)
            let login = LoginWithMnemonicViewController(action: .signInWithMixinMnemonics(mnemonics))
            navigationController?.pushViewController(login, animated: true)
        } catch {
            errorDescriptionLabel.text = R.string.localizable.invalid_mnemonic_phrase()
            errorDescriptionLabel.isHidden = false
            signInButton.isEnabled = false
        }
    }
    
}
