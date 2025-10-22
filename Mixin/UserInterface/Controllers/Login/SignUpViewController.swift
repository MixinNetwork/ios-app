import UIKit
import MixinServices

final class SignUpViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var loginButton: StyledButton!
    
    private let footerReuseIdentifier = "f"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = R.string.localizable.create_account()
        navigationItem.rightBarButtonItem = .customerService(target: self, action: #selector(presentCustomerService(_:)))
        
        tableView.register(R.nib.signUpMethodCell)
        tableView.register(FooterView.self, forHeaderFooterViewReuseIdentifier: footerReuseIdentifier)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.reloadData()
        
        loginButton.style = .tinted
        loginButton.setTitle(R.string.localizable.sign_up_have_account(), for: .normal)
        loginButton.titleLabel?.setFont(scaledFor: .systemFont(ofSize: 16, weight: .medium), adjustForContentSize: true)
    }
    
    @IBAction func login(_ sender: Any) {
        guard let navigationController else {
            return
        }
        var viewControllers = navigationController.viewControllers
        viewControllers.removeAll { viewController in
            !(viewController is OnboardingViewController)
        }
        viewControllers.append(SignInWithMobileNumberViewController())
        navigationController.setViewControllers(viewControllers, animated: true)
    }
    
    @objc private func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController(presentLoginLogsOnLongPressingTitle: true)
        present(customerService, animated: true)
        reporter.report(event: .customerServiceDialog, tags: ["source": "sign_up"])
    }
    
    private func description(keyword: String) -> NSAttributedString {
        let string = R.string.localizable.create_introduction(keyword)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .caption1),
            .foregroundColor: R.color.text_secondary()!,
        ]
        let attributedString = NSMutableAttributedString(string: string, attributes: attributes)
        let range = (string as NSString).range(of: keyword, options: .backwards)
        attributedString.addAttribute(.foregroundColor, value: R.color.theme()!, range: range)
        return attributedString
    }
    
}

extension SignUpViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.sign_up_method, for: indexPath)!
        if indexPath.section == 0 {
            cell.iconImageView.image = R.image.signup_phone()
            cell.titleLabel.text = R.string.localizable.mobile_phone()
            cell.descriptionLabel.attributedText = description(keyword: R.string.localizable.convenience())
        } else {
            cell.iconImageView.image = R.image.signup_mnemonic()
            cell.titleLabel.text = R.string.localizable.mnemonic_phrase()
            cell.descriptionLabel.attributedText = description(keyword: R.string.localizable.privacy())
        }
        return cell
    }
    
}

extension SignUpViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        10
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        if section == 1 {
            UITableView.automaticDimension
        } else {
            .leastNormalMagnitude
        }
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        guard section == 1 else {
            return nil
        }
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: footerReuseIdentifier) as! FooterView
        view.textView.attributedText = .agreement()
        return view
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let controller: UIViewController
        if indexPath.section == 0 {
            controller = SignUpWithMobileNumberViewController()
            reporter.report(event: .signUpStart, tags: ["type": "phone_number"])
        } else {
            if let entropy = AppGroupKeychain.mnemonics,
               let mnemonics = try? MixinMnemonics(entropy: entropy)
            {
                controller = LoginWithMnemonicViewController(action: .signIn(mnemonics))
            } else {
                controller = SignUpWithMnemonicIntroductionViewController()
            }
            reporter.report(event: .signUpStart, tags: ["type": "mnemonic_phrase"])
        }
        navigationController?.pushViewController(controller, animated: true)
    }
    
}

extension SignUpViewController {

    private class FooterView: UITableViewHeaderFooterView {
        
        let textView = IntroTextView()
        
        override init(reuseIdentifier: String?) {
            super.init(reuseIdentifier: reuseIdentifier)
            loadSubviews()
        }
        
        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
            loadSubviews()
        }
        
        private func loadSubviews() {
            contentView.backgroundColor = R.color.background()
            contentView.addSubview(textView)
            textView.backgroundColor = R.color.background()
            textView.isScrollEnabled = false
            textView.isEditable = false
            textView.isSelectable = true
            textView.snp.makeConstraints { make in
                let inset = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
                make.edges.equalToSuperview().inset(inset).priority(.almostRequired)
            }
        }
        
    }
    
}
