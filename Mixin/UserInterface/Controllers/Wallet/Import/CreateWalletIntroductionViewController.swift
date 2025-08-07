import UIKit

final class CreateWalletIntroductionViewController: IntroductionViewController {
    
    private let request: CreateWalletRequest
    
    init(request: CreateWalletRequest) {
        self.request = request
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        imageViewTopConstraint.constant = switch ScreenHeight.current {
        case .short:
            24
        case .medium:
            48
        case .long, .extraLong:
            72
        }
        contentLabelTopConstraint.constant = 16
        imageView.image = R.image.mnemonic_phrase()
        titleLabel.text = R.string.localizable.create_new_wallet()
        contentLabel.attributedText = .orderedList(
            items: [
                R.string.localizable.create_new_wallet_instruction_1(),
                R.string.localizable.create_new_wallet_instruction_2(),
                R.string.localizable.create_new_wallet_instruction_3(),
            ]
        ) { index in
            index < 2 ? R.color.text()! : R.color.error_red()!
        }
        actionButton.titleLabel?.setFont(
            scaledFor: .systemFont(ofSize: 16, weight: .medium),
            adjustForContentSize: true
        )
        actionButton.setTitle(R.string.localizable.create(), for: .normal)
        actionButton.addTarget(self, action: #selector(create(_:)), for: .touchUpInside)
    }
    
    @objc private func create(_ sender: Any) {
        let importing = AddWalletImportingViewController(
            importingWallet: .byCreating(request: request)
        )
        navigationController?.pushViewController(replacingCurrent: importing, animated: true)
    }
    
}
