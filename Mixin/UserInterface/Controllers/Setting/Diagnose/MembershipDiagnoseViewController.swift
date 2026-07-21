import UIKit
import StoreKit
import MixinServices

final class MembershipDiagnoseViewController: UIViewController {
    
    @IBOutlet weak var textView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = R.string.localizable.diagnose()
        navigationItem.rightBarButtonItem = .button(
            title: R.string.localizable.copy(),
            target: self,
            action: #selector(copyResults(_:))
        )
        textView.layer.cornerRadius = 8
        textView.layer.masksToBounds = true
        if AppStore.canMakePayments {
            textView.text += "AppStore: Can make payments\n"
            SafeAPI.membershipPlans { [weak self] result in
                switch result {
                case let .success(membership):
                    self?.reloadData(membership: membership)
                case let .failure(error):
                    self?.textView.text += "\(error)"
                }
            }
        } else {
            textView.text += "AppStore: Can't make payments\n"
        }
    }
    
    private func reloadData(membership: SafeMembership) {
        let productIDs = membership.plans.map(\.appleSubscriptionID)
        textView.text += "Request: \(productIDs)\n"
        Task { [weak textView] in
            if let country = await Storefront.current?.countryCode {
                textView?.text += "Storefront: \(country)\n"
            } else {
                textView?.text += "Missing storefront\n"
            }
            do {
                if #available(iOS 16.0, *) {
                    switch try await AppTransaction.shared {
                    case let .unverified(tx, _), let .verified(tx):
                        textView?.text += "Env: \(tx.environment.rawValue)\n"
                    }
                } else {
                    textView?.text += "Skipped on iOS 15"
                }
            } catch {
                textView?.text += "Env: \(error)\n"
            }
            do {
                let products = try await Product.products(for: productIDs)
                await MainActor.run {
                    textView?.text += "Available products: \(products.map(\.id))\n"
                }
            } catch {
                textView?.text += "\(error)\n"
            }
        }
    }
    
    @objc private func copyResults(_ sender: Any) {
        UIPasteboard.general.string = textView.text
        showAutoHiddenHud(style: .notification, text: R.string.localizable.copied())
    }
    
}
