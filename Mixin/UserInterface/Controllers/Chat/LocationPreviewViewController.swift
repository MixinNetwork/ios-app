import UIKit
import MixinServices
import MapKit

class LocationPreviewViewController: LocationViewController {
    
    override var minTableWrapperHeight: CGFloat {
        tableView.rowHeight + tableView.sectionHeaderHeight + view.safeAreaInsets.bottom
    }
    
    // https://developers.google.com/maps/documentation/urls/ios-urlscheme
    private lazy var googleMapUrl = URL(string: "comgooglemaps://?center=\(location.latitude),\(location.longitude)")!
    
    // https://lbs.amap.com/api/amap-mobile/guide/ios/marker
    private lazy var gaodeMapUrl = URL(string: "iosamap://viewMap?sourceApplication=Mixin+Messenger&poiname=A&lat=\(location.latitude)&lon=\(location.longitude)&dev=1")!
    
    private var location: Location!
    
    convenience init(location: Location) {
        self.init(nib: R.nib.locationView)
        self.location = location
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.showsUserLocation = false
        mapView.delegate = self
        let region = MKCoordinateRegion(center: location.gcj02CompatibleCoordinate,
                                        latitudinalMeters: 5000,
                                        longitudinalMeters: 5000)
        mapView.setRegion(region, animated: false)
        mapView.addAnnotation(location)
        
        tableView.dataSource = self
        tableView.delegate = self
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateTableViewMaskAndHeaderView()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        openLocationInExternalMapApp()
    }
    
    private func openLocationInExternalMapApp() {
        let controller = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        if UIApplication.shared.canOpenURL(googleMapUrl) {
            controller.addAction(UIAlertAction(title: R.string.localizable.chat_open_external_maps_google(), style: .default, handler: { (_) in
                UIApplication.shared.open(self.googleMapUrl, options: [:], completionHandler: nil)
            }))
        }
        if UIApplication.shared.canOpenURL(gaodeMapUrl) {
            controller.addAction(UIAlertAction(title: R.string.localizable.chat_open_external_maps_gaode(), style: .default, handler: { (_) in
                UIApplication.shared.open(self.gaodeMapUrl, options: [:], completionHandler: nil)
            }))
        }
        controller.addAction(UIAlertAction(title: R.string.localizable.chat_open_external_maps_apple(), style: .default, handler: { (_) in
            self.location.mapItem.openInMaps(launchOptions: nil)
        }))
        controller.addAction(UIAlertAction(title: R.string.localizable.dialog_button_cancel(), style: .cancel, handler: nil))
        present(controller, animated: true, completion: nil)
    }
    
}

extension LocationPreviewViewController: ContainerViewControllerDelegate {
    
    func barRightButtonTappedAction() {
        openLocationInExternalMapApp()
    }
    
    func imageBarRightButton() -> UIImage? {
        R.image.ic_open_external()
    }
    
}

extension LocationPreviewViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        mapView.dequeueReusableAnnotationView(withIdentifier: annotationReuseId, for: annotation)
    }
    
}

extension LocationPreviewViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.location, for: indexPath)!
        cell.render(location: location)
        cell.showsNavigationImageView = true
        return cell
    }
    
}
