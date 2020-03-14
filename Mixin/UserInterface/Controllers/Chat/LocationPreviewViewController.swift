import UIKit
import MixinServices
import MapKit

class LocationPreviewViewController: LocationViewController {
    
    override var minTableWrapperHeight: CGFloat {
        62 + 7 + view.safeAreaInsets.bottom
    }
    
    private let annotationReuseId = "anno"
    
    // https://developers.google.com/maps/documentation/urls/ios-urlscheme
    private lazy var googleMapUrl = URL(string: "https://www.google.com/maps/@42.585444,13.007813,6z")!
    
    // https://lbs.amap.com/api/amap-mobile/guide/ios/marker
    private lazy var gaodeMapUrl = URL(string: "iosamap://viewMap?sourceApplication=Mixin+Messenger&poiname=A&lat=39.98848272&lon=116.47560823&dev=1")!
    
    private var location: Location!
    
    convenience init(location: Location) {
        self.init(nib: R.nib.locationView)
        self.location = location
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.showsUserLocation = false
        mapView.delegate = self
        mapView.register(MKAnnotationView.self,
                         forAnnotationViewWithReuseIdentifier: annotationReuseId)
        let region = MKCoordinateRegion(center: location.coordinate,
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
        let view = mapView.dequeueReusableAnnotationView(withIdentifier: annotationReuseId, for: annotation)
        view.image = R.image.conversation.ic_annotation_pin()
        return view
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

extension LocationPreviewViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        openLocationInExternalMapApp()
    }
    
}
