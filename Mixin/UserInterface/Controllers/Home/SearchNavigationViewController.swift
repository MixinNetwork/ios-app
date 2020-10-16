import UIKit

class SearchNavigationViewController: UINavigationController {
    
    var searchNavigationBar: SearchNavigationBar {
        return navigationBar as! SearchNavigationBar
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchNavigationBar.searchBoxView.textField.delegate = self
        prepareNavigationBar()
        if let vc = viewControllers.first as? HomeSearchViewController {
            searchNavigationBar.layoutSearchBoxView(insets: vc.navigationSearchBoxInsets)
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle {
            prepareNavigationBar()
        }
    }

    private func prepareNavigationBar() {
        let image = R.color.background()!.image
        navigationBar.setBackgroundImage(image, for: .default)
        navigationBar.shadowImage = image
        navigationBar.backIndicatorImage = R.image.ic_search_back()
        navigationBar.backIndicatorTransitionMaskImage = R.image.ic_search_back()
    }

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        super.pushViewController(viewController, animated: animated)
        if let vc = viewController as? (UIViewController & HomeSearchViewController) {
            vc.transitionCoordinator?.animateAlongsideTransition(in: self.searchNavigationBar, animation: { (_) in
                if vc.wantsNavigationSearchBox {
                    self.searchNavigationBar.layoutSearchBoxView(insets: vc.navigationSearchBoxInsets)
                    self.searchNavigationBar.searchBoxView.alpha = 1
                } else {
                    self.searchNavigationBar.searchBoxView.alpha = 0
                }
            }, completion: nil)
        }
    }
    
    override func popViewController(animated: Bool) -> UIViewController? {
        let popped = super.popViewController(animated: true)
        if let vc = topViewController as? (UIViewController & HomeSearchViewController) {
            vc.transitionCoordinator?.animateAlongsideTransition(in: self.searchNavigationBar, animation: { (_) in
                if vc.wantsNavigationSearchBox {
                    self.searchNavigationBar.layoutSearchBoxView(insets: vc.navigationSearchBoxInsets)
                    self.searchNavigationBar.searchBoxView.alpha = 1
                } else {
                    self.searchNavigationBar.searchBoxView.alpha = 0
                }
            }, completion: nil)
        }
        return popped
    }
    
}

extension SearchNavigationViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
    
}
