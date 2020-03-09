import UIKit
import MixinServices
import MapKit

class LocationPreviewViewController: UIViewController {
    
    let location: Location
    
    var mapView: MKMapView {
        view as! MKMapView
    }
    
    private let annotationReuseId = "anno"
    
    // https://developers.google.com/maps/documentation/urls/ios-urlscheme
    private lazy var googleMapUrl = URL(string: "https://www.google.com/maps/@42.585444,13.007813,6z")!
    
    // https://lbs.amap.com/api/amap-mobile/guide/ios/marker
    private lazy var gaodeMapUrl = URL(string: "iosamap://viewMap?sourceApplication=Mixin+Messenger&poiname=A&lat=39.98848272&lon=116.47560823&dev=1")!
    
    init(location: Location) {
        self.location = location
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Xib/Storyboard is unsupported")
    }
    
    override func loadView() {
        view = MKMapView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
        mapView.register(LocationPreviewAnnotationView.self,
                         forAnnotationViewWithReuseIdentifier: annotationReuseId)
        let region = MKCoordinateRegion(center: location.coordinate,
                                        latitudinalMeters: 5000,
                                        longitudinalMeters: 5000)
        mapView.setRegion(region, animated: false)
        mapView.addAnnotation(location)
    }
    
}

extension LocationPreviewViewController: ContainerViewControllerDelegate {
    
    func barRightButtonTappedAction() {
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
    
    func imageBarRightButton() -> UIImage? {
        R.image.ic_open_external()
    }
    
}

extension LocationPreviewViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let location = annotation as? Location else {
            return nil
        }
        let view = mapView.dequeueReusableAnnotationView(withIdentifier: annotationReuseId, for: annotation) as! LocationPreviewAnnotationView
        view.titleLabel.text = location.name
        view.subtitleLabel.text = location.address
        return view
    }
    
}
