import UIKit
import MixinServices

final class SignInMethodSelectorViewController: UIViewController {
    
    @IBOutlet weak var trayView: UIView!
    @IBOutlet weak var agreementTextView: IntroTextView!
    @IBOutlet weak var signUpButton: UIButton!
    
    private weak var collectionView: UICollectionView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.sign_in()
        navigationItem.rightBarButtonItem = .customerService(
            target: self,
            action: #selector(presentCustomerService(_:))
        )
        let layout = UICollectionViewCompositionalLayout { sectionIndex, environment in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(65))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let group: NSCollectionLayoutGroup = .horizontal(layoutSize: itemSize, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.boundarySupplementaryItems = [
                NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(37)),
                    elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top
                )
            ]
            section.interGroupSpacing = 10
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
            return section
        }
        layout.configuration.interSectionSpacing = 10
        let collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.backgroundColor = R.color.background_secondary()
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.bottom.equalTo(trayView.snp.top)
        }
        self.collectionView = collectionView
        collectionView.register(R.nib.signInMethodCell)
        collectionView.register(
            R.nib.signInMethodHeaderView,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader
        )
        collectionView.dataSource = self
        collectionView.delegate = self
        agreementTextView.attributedText = .agreement()
        signUpButton.configuration?.attributedTitle = AttributedString(
            string: R.string.localizable.sign_in_no_account(),
            scalingByFontSize: 16,
            weight: .medium
        )
    }
    
    @IBAction func signUp(_ sender: Any) {
        let intro = CreateAccountIntroductionViewController(signUpSource: "login_by")
        present(intro, animated: true)
    }
    
    @objc private func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController(presentLoginLogsOnLongPressingTitle: true)
        present(customerService, animated: true)
        reporter.report(event: .customerServiceDialog, tags: ["source": "login_mnemonic_phrase"])
    }
    
}

extension SignInMethodSelectorViewController: NavigationBarStyling {
    
    var navigationBarStyle: NavigationBarStyle {
        .secondaryBackground
    }
    
}

extension SignInMethodSelectorViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        Section.allCases.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch Section.allCases[section] {
        case .fromOtherWallets:
            FromOtherWalletsMethod.allCases.count
        case .mixinRecoveryKit:
            MixinRecoveryKitMethod.allCases.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.sign_in_method, for: indexPath)!
        switch Section.allCases[indexPath.section] {
        case .fromOtherWallets:
            switch FromOtherWalletsMethod.allCases[indexPath.item] {
            case .mnemonicPhrases:
                cell.iconImageView.image = R.image.sign_in_mnemonics()
                cell.titleLabel.text = R.string.localizable.login_method_mnemonic_12_24_title()
                cell.descriptionLabel.text = R.string.localizable.login_method_mnemonic_12_24_desc()
            }
        case .mixinRecoveryKit:
            switch MixinRecoveryKitMethod.allCases[indexPath.item] {
            case .phoneNumber:
                cell.iconImageView.image = R.image.sign_in_phone()
                cell.titleLabel.text = R.string.localizable.login_method_mobile_title()
                cell.descriptionLabel.text = R.string.localizable.login_method_mobile_desc()
            case .mnemonicPhrases:
                cell.iconImageView.image = R.image.sign_in_mnemonics()
                cell.titleLabel.text = R.string.localizable.login_method_mnemonic_13_25_title()
                cell.descriptionLabel.text = R.string.localizable.login_method_mnemonic_13_25_desc()
            }
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: R.reuseIdentifier.sign_in_method_header, for: indexPath)!
        switch Section.allCases[indexPath.section] {
        case .fromOtherWallets:
            header.label.text = R.string.localizable.login_method_from_other_wallets()
        case .mixinRecoveryKit:
            header.label.text = R.string.localizable.login_method_recovery_kit()
        }
        return header
    }
    
}

extension SignInMethodSelectorViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let next = switch Section.allCases[indexPath.section] {
        case .fromOtherWallets:
            switch FromOtherWalletsMethod.allCases[indexPath.item] {
            case .mnemonicPhrases:
                SignInWithBIP39MnemonicsViewController(analyticSource: "login_by")
            }
        case .mixinRecoveryKit:
            switch MixinRecoveryKitMethod.allCases[indexPath.item] {
            case .phoneNumber:
                SignInWithMobileNumberViewController(loginSource: "login_by")
            case .mnemonicPhrases:
                SignInWithMixinMnemonicsViewController(analyticSource: "login_by")
            }
        }
        navigationController?.pushViewController(next, animated: true)
    }
    
}

extension SignInMethodSelectorViewController {
    
    private enum Section: CaseIterable {
        case fromOtherWallets
        case mixinRecoveryKit
    }
    
    private enum FromOtherWalletsMethod: CaseIterable {
        case mnemonicPhrases
    }
    
    private enum MixinRecoveryKitMethod: CaseIterable {
        case phoneNumber
        case mnemonicPhrases
    }
    
}
