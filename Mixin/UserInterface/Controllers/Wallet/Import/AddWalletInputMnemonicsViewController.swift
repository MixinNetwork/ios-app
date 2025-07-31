import UIKit

final class AddWalletInputMnemonicsViewController: InputBIP39MnemonicsViewController {
    
    private var mnemonics: (plain: BIP39Mnemonics, encrypted: EncryptedBIP39Mnemonics)?
    
    override func confirm(_ sender: Any) {
        guard let mnemonics else {
            return
        }
        let fetchAddress = AddWalletFetchAddressViewController(
            mnemonics: mnemonics.plain,
            encryptedMnemonics: mnemonics.encrypted
        )
        navigationController?.pushViewController(fetchAddress, animated: true)
    }
    
    override func detectPhrases(_ sender: Any) {
        let phrases = self.textFieldPhrases
        if phrases.contains(where: \.isEmpty) {
            mnemonics = nil
            errorDescriptionLabel.isHidden = true
            confirmButton.isEnabled = false
        } else {
            do {
                let plain = try BIP39Mnemonics(phrases: phrases)
                let encrypted = try EncryptedBIP39Mnemonics(
                    mnemonics: plain,
                    key: encryptionKey
                )
                mnemonics = (plain: plain, encrypted: encrypted)
                errorDescriptionLabel.isHidden = true
                confirmButton.isEnabled = true
            } catch {
                mnemonics = nil
                errorDescriptionLabel.text = R.string.localizable.invalid_mnemonic_phrase()
                errorDescriptionLabel.isHidden = false
                confirmButton.isEnabled = false
            }
        }
    }
    
}
