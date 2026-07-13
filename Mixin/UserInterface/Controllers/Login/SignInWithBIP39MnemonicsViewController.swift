import UIKit
import MixinServices

final class SignInWithBIP39MnemonicsViewController: SignInWithMnemonicsViewController<BIP39Mnemonics.PhrasesCount> {
    
    init() {
        super.init(phrasesCount: .medium)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let footer = R.nib.signInWithBIP39MnemonicsFooterView(withOwner: nil)!
        contentStackView.addArrangedSubview(footer)
        reporter.report(event: .loginMnemonicPhrase)
    }
    
    override func reloadViews(count: BIP39Mnemonics.PhrasesCount) {
        super.reloadViews(count: count)
        addRowStackViewForButtonsIntoInputStackView()
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
        addButtonIntoInputFields(
            image: R.image.explore.web3_send_delete()!,
            title: R.string.localizable.clear(),
            action: #selector(emptyPhrases(_:))
        )
    }
    
    override func signIn(_ sender: Any) {
        do {
            let walletMnemonics = try BIP39Mnemonics(phrases: textFieldPhrases)
            let loginMnemonics = try MixinMnemonics(entropy: walletMnemonics.entropy)
            let login = LoginWithMnemonicViewController(
                action: .signInWithBIP39Mnemonics(loginMnemonics)
            )
            navigationController?.pushViewController(login, animated: true)
        } catch {
            errorDescriptionLabel.text = R.string.localizable.invalid_mnemonic_phrase()
            errorDescriptionLabel.isHidden = false
            signInButton.isEnabled = false
        }
    }
    
    override func arePhrasesValid(_ phrases: [String]) -> Bool {
        BIP39Mnemonics.areValid(phrases: phrases)
    }
    
}
