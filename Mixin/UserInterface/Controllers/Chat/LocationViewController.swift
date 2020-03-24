import UIKit
import MapKit

class LocationViewController: UIViewController {
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var tableWrapperView: LocationTableWrapperView!
    @IBOutlet weak var tableView: UITableView!
    
    let headerReuseId = "header"
    let pinAnnotationReuseId = "anno"
    let tableHeaderView = UIView()
    
    var tableWrapperMaskHeight: CGFloat {
        get {
            tableWrapperMaskView.frame.height
        }
        set {
            tableWrapperMaskView.frame = CGRect(x: 0,
                                                y: view.bounds.height - newValue,
                                                width: view.bounds.width,
                                                height: newValue)
            mapView.layoutMargins.bottom = newValue - view.safeAreaInsets.bottom
        }
    }
    
    var minTableWrapperMaskHeight: CGFloat {
        view.bounds.height / 2
    }
    
    private let tableWrapperMaskView = UIView()
    
    private var lastViewHeight: CGFloat = 0
    
    private var maxTableWrapperMaskHeight: CGFloat {
        max(view.bounds.height - 160, minTableWrapperMaskHeight)
    }
    
    convenience init() {
        self.init(nib: R.nib.locationView)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.register(PinAnnotationView.self,
                         forAnnotationViewWithReuseIdentifier: pinAnnotationReuseId)
        if let popRecognizer = navigationController?.interactivePopGestureRecognizer {
            var recognizersIncludingSubviews = mapView.subviews
                .compactMap({ $0.gestureRecognizers })
                .flatMap({ $0 })
            if let recognizers = mapView.gestureRecognizers {
                recognizersIncludingSubviews.append(contentsOf: recognizers)
            }
            for recognizer in recognizersIncludingSubviews {
                recognizer.require(toFail: popRecognizer)
            }
        }
        tableView.register(R.nib.locationCell)
        tableView.register(UITableViewHeaderFooterView.self,
                           forHeaderFooterViewReuseIdentifier: headerReuseId)
        tableWrapperMaskView.isUserInteractionEnabled = false
        tableWrapperMaskView.backgroundColor = .black
        tableWrapperMaskView.layer.cornerRadius = 13
        tableWrapperMaskView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        tableWrapperMaskView.layer.masksToBounds = true
        tableWrapperMaskView.layer.backgroundColor = UIColor.black.cgColor
        tableWrapperView.mask = tableWrapperMaskView
        tableView.delegate = self
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        if view.bounds.height != lastViewHeight {
            resetTableWrapperMaskHeightAndHeaderView()
            lastViewHeight = view.bounds.height
        }
    }
    
    func resetTableWrapperMaskHeightAndHeaderView() {
        tableWrapperMaskHeight = minTableWrapperMaskHeight
        let headerSize = CGSize(width: tableView.frame.width,
                                height: view.bounds.height - minTableWrapperMaskHeight)
        tableHeaderView.frame = CGRect(origin: .zero, size: headerSize)
        tableView.tableHeaderView = tableHeaderView
    }
    
}

extension LocationViewController: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard tableView.isTracking || tableView.isDecelerating else {
            return
        }
        let tableViewContentTop = tableView.convert(CGPoint.zero, to: tableWrapperView).y + tableHeaderView.frame.height
        var preferredWrapperHeight = tableWrapperView.bounds.height - tableViewContentTop
        preferredWrapperHeight = min(preferredWrapperHeight, maxTableWrapperMaskHeight)
        tableWrapperMaskHeight = preferredWrapperHeight
    }
    
    func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        UIView.animate(withDuration: 0.3) {
            self.tableWrapperMaskHeight = self.minTableWrapperMaskHeight
        }
        return true
    }
    
}

extension LocationViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section == 0 ? tableView.sectionHeaderHeight : .leastNormalMagnitude
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        .leastNormalMagnitude
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = tableView.dequeueReusableHeaderFooterView(withIdentifier: headerReuseId)!
        view.contentView.backgroundColor = .background
        return view
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        nil
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
    }
    
}
