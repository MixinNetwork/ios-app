import UIKit
import StoreKit

final class MembershipPlansViewController: UIViewController {
    
    @IBOutlet weak var buyButton: StyledButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        buyButton.style = .filled
        buyButton.applyDefaultContentInsets()
        buyButton.setTitle("Buy Elite", for: .normal)
        buyButton.titleLabel?.setFont(
            scaledFor: .systemFont(ofSize: 16, weight: .medium),
            adjustForContentSize: true
        )
    }
    
    @IBAction func buy(_ sender: Any) {
        Task {
            let title: String
            let description: String?
            do {
                let products = try await Product.products(for: ["one.mixin.messenger.membership.elite"])
                let product = products[0]
                let result = try await product.purchase()
                switch result {
                case .success(let verification):
                    switch verification {
                    case .verified(let transaction):
                        title = "Verified"
                        description = String(data: transaction.jsonRepresentation, encoding: .utf8) ?? "Invalid"
                    case .unverified:
                        title = "unverified"
                        description = nil
                    }
                case .userCancelled:
                    title = "userCancelled"
                    description = nil
                case .pending:
                    fallthrough
                @unknown default:
                    title = "\(result)"
                    description = nil
                }
            } catch {
                title = "Error"
                description = "\(error)"
            }
            await MainActor.run {
                let alert = UIAlertController(title: title, message: description, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Copy", style: .default, handler: { _ in
                    UIPasteboard.general.string = description
                }))
                self.present(alert, animated: true)
            }
        }
    }
    
}
