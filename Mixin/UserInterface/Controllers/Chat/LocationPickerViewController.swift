import UIKit
import CoreLocation
import MapKit
import MixinServices
import Alamofire

class LocationPickerViewController: UIViewController {
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var scrollToUserLocationButton: UIButton!
    
    class func instance(conversationInputViewController: ConversationInputViewController) -> UIViewController {
        let vc = R.storyboard.chat.location_picker()!
        vc.input = conversationInputViewController
        return ContainerViewController.instance(viewController: vc, title: R.string.localizable.chat_menu_location())
    }
    
    private let annotationReuseId = "anno"
    
    private var input: ConversationInputViewController!
    private var nearbyLocationsRequest: Request?
    private var locations: [FoursquareLocation] = []
    
    private var userLocationAccuracy: String {
        if let accuracy = mapView.userLocation.location?.horizontalAccuracy {
            if accuracy > 0 {
                return "\(accuracy)m"
            } else {
                return ">1km"
            }
        } else {
            return ">1km"
        }
    }
    
    private lazy var manager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.desiredAccuracy = kCLLocationAccuracyBest
        return manager
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if let imageView = scrollToUserLocationButton.imageView {
            imageView.contentMode = .center
            imageView.clipsToBounds = false
        }
        mapView.register(UserLocationAnnotationView.self,
                         forAnnotationViewWithReuseIdentifier: annotationReuseId)
        mapView.delegate = self
        mapView.userTrackingMode = .follow
        tableView.dataSource = self
        tableView.delegate = self
        if mapView.userLocation.coordinate.latitude != 0 || mapView.userLocation.coordinate.longitude != 0 {
            reloadLocations(coordinate: mapView.userLocation.coordinate)
        }
        let isAuthorized = CLLocationManager.authorizationStatus() == .authorizedAlways
            || CLLocationManager.authorizationStatus() == .authorizedWhenInUse
        if isAuthorized {
            
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        switch CLLocationManager.authorizationStatus() {
        case .authorizedAlways, .authorizedWhenInUse:
            break
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            fallthrough
        @unknown default:
            break
        }
    }
    
    @IBAction func scrollToUserLocationAction(_ sender: Any) {
        mapView.setCenter(mapView.userLocation.coordinate, animated: true)
    }
    
}

extension LocationPickerViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        mapView.dequeueReusableAnnotationView(withIdentifier: annotationReuseId, for: annotation)
    }
    
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        reloadLocations(coordinate: userLocation.coordinate)
        if let cell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? LocationCell {
            cell.subtitleLabel.text = R.string.localizable.chat_location_accuracy(userLocationAccuracy)
        }
    }
    
}

extension LocationPickerViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? 1 : locations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.location, for: indexPath)!
        if indexPath.section == 0 {
            cell.renderAsCurrentLocation(accuracy: userLocationAccuracy)
        } else {
            let location = locations[indexPath.row]
            cell.render(location: location)
        }
        return cell
    }
    
}

extension LocationPickerViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            if let location = mapView.userLocation.location {
                send(coordinate: location.coordinate, name: nil, address: nil)
            } else {
                alert(R.string.localizable.chat_user_location_undetermined())
            }
        } else {
            let location = locations[indexPath.row]
            send(coordinate: location.coordinate, name: location.name, address: location.address)
        }
    }
    
}

extension LocationPickerViewController {
    
    private func reloadLocations(coordinate: CLLocationCoordinate2D) {
        nearbyLocationsRequest?.cancel()
        nearbyLocationsRequest = FoursquareAPI.search(coordinate: coordinate) { [weak self] (result) in
            guard let self = self else {
                return
            }
            switch result {
            case .success(let locations):
                self.locations = locations
                self.tableView.reloadSections(IndexSet(integer: 1), with: .automatic)
            case .failure:
                break
            }
        }
    }
    
    private func send(coordinate: CLLocationCoordinate2D, name: String?, address: String?) {
        let location = Location(latitude: coordinate.latitude,
                                longitude: coordinate.longitude,
                                name: name,
                                address: address)
        do {
            try input.send(location: location)
            navigationController?.popViewController(animated: true)
        } catch {
            reporter.report(error: error)
            showAutoHiddenHud(style: .error, text: R.string.localizable.chat_send_location_failed())
        }
    }
    
}
