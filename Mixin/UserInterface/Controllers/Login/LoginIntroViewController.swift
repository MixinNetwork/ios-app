import UIKit

class LoginIntroViewController: UIViewController {

    @IBOutlet weak var introTextView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let font = introTextView.font
        let intro = String(format: Localized.TEXT_INTRO,
                           Localized.BUTTON_TITLE_AGREE_AND_CONTINUE,
                           Localized.BUTTON_TITLE_TERMS_OF_SERVICE,
                           Localized.BUTTON_TITLE_PRIVACY_POLICY)
        let nsIntro = intro as NSString
        let fullRange = NSRange(location: 0, length: nsIntro.length)
        let termsRange = nsIntro.range(of: Localized.BUTTON_TITLE_TERMS_OF_SERVICE)
        let privacyRange = nsIntro.range(of: Localized.BUTTON_TITLE_PRIVACY_POLICY)
        let attributedText = NSMutableAttributedString(string: intro)
        let paragraphSytle = NSMutableParagraphStyle()
        paragraphSytle.alignment = .center
        attributedText.setAttributes([NSAttributedString.Key.paragraphStyle: paragraphSytle], range: fullRange)
        if let font = font {
            attributedText.addAttributes([NSAttributedString.Key.font: font], range: fullRange)
        }
        attributedText.addAttributes([NSAttributedString.Key.link: URL.terms], range: termsRange)
        attributedText.addAttributes([NSAttributedString.Key.link: URL.privacy], range: privacyRange)
        introTextView.attributedText = attributedText
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Preload country code library for a more rapid push animation
        _ = CountryCodeLibrary.shared
    }

}
