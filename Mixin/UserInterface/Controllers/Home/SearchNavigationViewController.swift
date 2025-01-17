import UIKit

class SearchNavigationViewController: UINavigationController {
    
    var searchNavigationBar: SearchNavigationBar {
        return navigationBar as! SearchNavigationBar
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        searchNavigationBar.searchBoxView.textField.delegate = self
        prepareNavigationBar()
        if let vc = viewControllers.first as? SearchNavigationControllerChild {
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
        let backIndicatorImage = R.image.ic_search_back()
        let backgroundColor = R.color.background()
        let image = backgroundColor!.image
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = backgroundColor
        appearance.shadowImage = image
        appearance.setBackIndicatorImage(backIndicatorImage, transitionMaskImage: backIndicatorImage)
        appearance.titleTextAttributes = [.foregroundColor: UIColor.clear]
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
    }

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        super.pushViewController(viewController, animated: animated)
        if let vc = viewController as? (UIViewController & SearchNavigationControllerChild) {
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
        if let vc = topViewController as? (UIViewController & SearchNavigationControllerChild) {
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
