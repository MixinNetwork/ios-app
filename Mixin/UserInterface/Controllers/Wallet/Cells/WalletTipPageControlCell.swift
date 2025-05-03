import UIKit

final class WalletTipPageControlCell: UICollectionViewCell {
    
    weak var pageControl: UIPageControl!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        loadSubviews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        loadSubviews()
    }
    
    func configure(with numberOfPages: Int, currentPage: Int) {
        pageControl.numberOfPages = numberOfPages
        pageControl.currentPage = currentPage
    }
    
    private func loadSubviews() {
        let pageControl = UIPageControl()
        pageControl.currentPageIndicatorTintColor = R.color.background_tinted()
        pageControl.pageIndicatorTintColor = R.color.button_background_disabled()
        contentView.addSubview(pageControl)
        pageControl.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        self.pageControl = pageControl
    }
    
}
