import UIKit
import CoreLocation
import MapKit
import MixinServices
import Alamofire

class LocationPickerViewController: LocationViewController {
    
    @IBOutlet weak var searchBoxView: SearchBoxView? {
        didSet {
            if let textField = oldValue?.textField {
                textField.removeTarget(self, action: nil, for: .editingChanged)
                textField.delegate = nil
            }
            if let textField = searchBoxView?.textField {
                textField.addTarget(self, action: #selector(search(_:)), for: .editingChanged)
                textField.keyboardType = .webSearch
                textField.delegate = self
            }
        }
    }
    
    override var tableViewMaskHeight: CGFloat {
        didSet {
            pinImageViewIfLoaded?.center = pinImageViewCenter
            scrollToUserLocationButtonBottomConstraint.constant = tableViewMaskHeight + 20
            let point: CGPoint?
            if let result = pickedSearchResult {
                point = mapView.convert(result.gcj02CompatibleCoordinate, toPointTo: mapView)
            } else if userDidDropThePin {
                point = mapView.convert(mapView.centerCoordinate, toPointTo: mapView)
            } else {
                point = nil
            }
            if var point = point {
                point.y += (tableViewMaskHeight - oldValue) / 2
                let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
                mapView.setCenter(coordinate, animated: false)
            }
        }
    }
    
    override var minTableWrapperHeight: CGFloat {
        if let keyboardHeight = keyboardHeightIfShow {
            return keyboardHeight + 2 * tableView.rowHeight + tableView.sectionHeaderHeight
        } else {
            return super.minTableWrapperHeight
        }
    }
    
    private let scrollToUserLocationButton = UIButton()
    private let pinImage = R.image.conversation.ic_annotation_pin()!
    private let nearbyLocationSearchingIndicator = ActivityIndicatorView()
    private let searchResultAnnotationReuseId = "search"
    
    private lazy var geocoder = CLGeocoder()
    private lazy var pinImageView = UIImageView(image: pinImage)
    private lazy var searchView = R.nib.locationSearchView(owner: self)!
    private lazy var locationManager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.delegate = self
        return manager
    }()
    
    private weak var pinImageViewIfLoaded: UIImageView?
    
    private var input: ConversationInputViewController!
    private var scrollToUserLocationButtonBottomConstraint: NSLayoutConstraint!
    private var userDidDropThePin = false
    private var userPinnedLocationAddress: String?
    private var nearbyLocationsRequest: Request?
    private var nearbyLocationsSearchCoordinate: CLLocationCoordinate2D?
    private var nearbyLocations: [Location] = []
    private var keyboardHeightIfShow: CGFloat?
    private var isKeyboardAnimating = false
    private var lastSearchRequest: Request?
    private var searchResults: [Location]?
    private var pickedSearchResult: Location?
    
    private var userLocationAccuracy: String {
        if let accuracy = locationManager.location?.horizontalAccuracy, accuracy > 0 {
            return "\(Int(accuracy))m"
        } else {
            return ">1km"
        }
    }
    
    private var pinImageViewCenter: CGPoint {
        CGPoint(x: view.bounds.midX, y: (view.bounds.height - tableViewMaskHeight) / 2 - pinImage.size.height / 2)
    }
    
    private var trimmedKeyword: String? {
        guard let trimmed = searchBoxView?.textField.text?.trimmingCharacters(in: .whitespaces) else {
            return nil
        }
        if trimmed.isEmpty {
            return nil
        } else {
            return trimmed
        }
    }
    
    convenience init(input: ConversationInputViewController) {
        self.init(nib: R.nib.locationView)
        self.input = input
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        locationManager.stopUpdatingLocation()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView.delegate = self
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .follow
        mapView.register(SearchResultAnnotationView.self,
                         forAnnotationViewWithReuseIdentifier: searchResultAnnotationReuseId)
        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(dropPinAction(_:)))
        mapView.addGestureRecognizer(panRecognizer)
        panRecognizer.delegate = self
        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(dropPinAction(_:)))
        mapView.addGestureRecognizer(pinchRecognizer)
        pinchRecognizer.delegate = self
        
        tableView.dataSource = self
        tableView.delegate = self
        
        view.addSubview(scrollToUserLocationButton)
        scrollToUserLocationButton.setImage(R.image.conversation.ic_scroll_to_user_location(), for: .normal)
        scrollToUserLocationButton.addTarget(self, action: #selector(scrollToUserLocationAction(_:)), for: .touchUpInside)
        scrollToUserLocationButton.snp.makeConstraints { (make) in
            make.width.height.equalTo(44)
            make.trailing.equalToSuperview().offset(-12)
        }
        scrollToUserLocationButtonBottomConstraint = view.bottomAnchor.constraint(equalTo: scrollToUserLocationButton.bottomAnchor)
        scrollToUserLocationButtonBottomConstraint.isActive = true
        if let imageView = scrollToUserLocationButton.imageView {
            imageView.contentMode = .center
            imageView.clipsToBounds = false
        }
        
        nearbyLocationSearchingIndicator.tintColor = .theme
        nearbyLocationSearchingIndicator.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 240)
        
        let center = NotificationCenter.default
        center.addObserver(self,
                           selector: #selector(keyboardWillChangeFrame(_:)),
                           name: UIResponder.keyboardWillChangeFrameNotification,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(keyboardDidEndAnimating(_:)),
                           name: UIResponder.keyboardDidShowNotification,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(keyboardDidEndAnimating(_:)),
                           name: UIResponder.keyboardDidHideNotification,
                           object: nil)
        
        locationManager.startUpdatingLocation()
        if let coordinate = locationManager.location?.coordinate, coordinate.latitude != 0 || coordinate.longitude != 0 {
            reloadNearbyLocations(coordinate: coordinate)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        switch CLLocationManager.authorizationStatus() {
        case .authorizedAlways, .authorizedWhenInUse:
            break
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            fallthrough
        @unknown default:
            if !userDidDropThePin {
                addUserPickedAnnotationAndRemoveThePlaceholder()
                userDidDropThePin = true
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let searchResults = searchResults {
            if pickedSearchResult == nil || indexPath.section == 1 {
                let picked = searchResults[indexPath.row]
                self.pickedSearchResult = picked
                tableView.reloadData()
                if let anno = mapView.annotations.compactMap({ $0 as? SearchResultAnnotation }).first(where: { $0.location == picked}) {
                    mapView.selectAnnotation(anno, animated: true)
                }
                mapView.setCenter(picked.gcj02CompatibleCoordinate, animated: true)
            } else if let result = pickedSearchResult, indexPath.section == 0 {
                send(coordinate: result.coordinate,
                     name: result.name,
                     address: result.address,
                     venueType: result.venueType)
            } else {
                assertionFailure("No way this is happening")
            }
        } else {
            if indexPath.section == 0 {
                if let anno = mapView.annotations.first(where: { $0 is UserPickedLocationAnnotation }) {
                    send(coordinate: anno.coordinate, name: nil, address: nil, venueType: nil)
                } else if let location = locationManager.location {
                    send(coordinate: location.coordinate,
                         name: nil,
                         address: nil,
                         venueType: nil)
                } else {
                    alert(R.string.localizable.chat_user_location_undetermined())
                }
            } else {
                let location = nearbyLocations[indexPath.row]
                send(coordinate: location.coordinate,
                     name: location.name,
                     address: location.address,
                     venueType: location.venueType)
            }
        }
    }
    
    @IBAction func cancelSearchAction(_ sender: Any) {
        searchBoxView?.textField.resignFirstResponder()
        searchResults = nil
        pickedSearchResult = nil
        tableView.reloadData()
        mapView.removeAnnotations(mapView.annotations)
        mapView.userTrackingMode = .follow
        mapView.setCenter(mapView.userLocation.coordinate, animated: true)
        UIView.animate(withDuration: 0.3, animations: {
            self.searchView.alpha = 0
        }) { (_) in
            self.searchBoxView?.textField.text = nil
            if let coordinate = self.locationManager.location?.coordinate {
                self.reloadNearbyLocations(coordinate: coordinate)
            }
            self.tableView.contentOffset.y = 0
            self.view.layoutIfNeeded()
            self.tableViewMaskHeight = self.minTableWrapperHeight
            self.view.layoutIfNeeded()
        }
    }
    
    @objc private func scrollToUserLocationAction(_ sender: Any) {
        userDidDropThePin = false
        let userPickedAnnotations = mapView.annotations.filter({ $0 is UserPickedLocationAnnotation })
        mapView.removeAnnotations(userPickedAnnotations)
        mapView.userTrackingMode = .follow
        mapView.setCenter(mapView.userLocation.coordinate, animated: true)
        UIView.animate(withDuration: 0.3, animations: {
            self.tableView.contentOffset = .zero
            self.tableViewMaskHeight = self.minTableWrapperHeight
        }) { (_) in
            if let coordinate = self.locationManager.location?.coordinate {
                self.reloadNearbyLocations(coordinate: coordinate)
            }
        }
    }
    
    @objc private func dropPinAction(_ recognizer: UIPanGestureRecognizer) {
        guard searchResults == nil else {
            return
        }
        userDidDropThePin = true
        guard recognizer.state == .began else {
            return
        }
        mapView.userTrackingMode = .none
        let userPickedAnnotations = mapView.annotations.filter({ $0 is UserPickedLocationAnnotation })
        mapView.removeAnnotations(userPickedAnnotations)
        if pinImageView.superview == nil {
            pinImageView.center = pinImageViewCenter
            view.addSubview(pinImageView)
            pinImageViewIfLoaded = pinImageView
        }
    }
    
    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        guard let endFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        isKeyboardAnimating = true
        let keyboardWillBeInvisible = (UIScreen.main.bounds.height - endFrame.origin.y) <= 1
        if keyboardWillBeInvisible {
            keyboardHeightIfShow = nil
        } else {
            keyboardHeightIfShow = endFrame.height
        }
        updateTableViewMaskAndHeaderView()
        view.layoutIfNeeded()
    }
    
    @objc private func keyboardDidEndAnimating(_ notification: Notification) {
        isKeyboardAnimating = false
    }
    
    @objc private func search(_ sender: UITextField) {
        guard let keyword = trimmedKeyword else {
            searchBoxView?.isBusy = false
            searchResults = nil
            tableView.reloadData()
            return
        }
        lastSearchRequest?.cancel()
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        perform(#selector(requestSearch(keyword:)), with: keyword, afterDelay: 1)
    }
    
    @objc private func requestSearch(keyword: String) {
        searchBoxView?.isBusy = true
        let coordinate: CLLocationCoordinate2D
        if let annotation = mapView.annotations.first(where: { $0 is UserPickedLocationAnnotation }) {
            coordinate = annotation.coordinate
        } else if let userLocation = locationManager.location {
            coordinate = userLocation.coordinate
        } else {
            coordinate = mapView.centerCoordinate
        }
        lastSearchRequest = FoursquareAPI.search(coordinate: coordinate, query: keyword, completion: { [weak self] (result) in
            guard let self = self else {
                return
            }
            let locations: [Location]?
            switch result {
            case .success(let resultLocations):
                if resultLocations.isEmpty {
                    locations = nil
                } else {
                    locations = resultLocations
                }
            case .failure(_):
                locations = nil
            }
            self.pickedSearchResult = nil
            self.searchResults = locations
            self.tableView.reloadData()
            self.searchBoxView?.isBusy = false
            self.mapView.removeAnnotations(self.mapView.annotations)
            if let annotations = locations?.map(SearchResultAnnotation.init) {
                self.mapView.addAnnotations(annotations)
            }
        })
    }
    
}

extension LocationPickerViewController: ContainerViewControllerDelegate {
    
    func barRightButtonTappedAction() {
        if searchView.superview == nil {
            container?.navigationBar.addSubview(searchView)
            searchView.snp.makeConstraints { (make) in
                make.leading.trailing.bottom.equalToSuperview()
                make.height.equalTo(44)
            }
        }
        searchView.alpha = 0
        UIView.animate(withDuration: 0.3) {
            self.searchView.alpha = 1
        }
        searchBoxView?.textField.becomeFirstResponder()
    }
    
    func imageBarRightButton() -> UIImage? {
        R.image.ic_title_search()
    }
    
}

extension LocationPickerViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if !userDidDropThePin, let location = locations.first {
            reloadNearbyLocations(coordinate: location.coordinate)
            reloadFirstCell()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            mapView.setCenter(mapView.userLocation.coordinate, animated: true)
            if let location = manager.location {
                reloadNearbyLocations(coordinate: location.coordinate)
                reloadFirstCell()
            }
        }
    }
    
}

extension LocationPickerViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is UserPickedLocationAnnotation {
            return mapView.dequeueReusableAnnotationView(withIdentifier: annotationReuseId, for: annotation)
        } else if annotation is SearchResultAnnotation {
            return mapView.dequeueReusableAnnotationView(withIdentifier: searchResultAnnotationReuseId, for: annotation)
        } else {
            return nil
        }
    }
    
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        let isUserDraggingCausedMapViewRegionChange = userDidDropThePin
            && !tableView.isTracking
            && !tableView.isDecelerating
            && !isKeyboardAnimating
        guard isUserDraggingCausedMapViewRegionChange else {
            return
        }
        geocoder.cancelGeocode()
        userPinnedLocationAddress = nil
        reloadFirstCell()
    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        guard userDidDropThePin && !isKeyboardAnimating else {
            return
        }
        guard searchResults == nil else {
            return
        }
        addUserPickedAnnotationAndRemoveThePlaceholder()
        guard !tableView.isTracking && !tableView.isDecelerating else {
            return
        }
        let coordinate = mapView.convert(pinImageViewCenter, toCoordinateFrom: view)
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        geocoder.reverseGeocodeLocation(location) { [weak self] (placemarks, error) in
            guard let self = self else {
                return
            }
            if let address = placemarks?.first?.postalAddress {
                self.userPinnedLocationAddress = address.street
            } else {
                self.userPinnedLocationAddress = ""
            }
            self.reloadFirstCell()
        }
        if tableView.contentOffset != .zero {
            UIView.animate(withDuration: 0.3, animations: {
                self.tableView.contentOffset = .zero
                self.tableViewMaskHeight = self.minTableWrapperHeight
                if let annotation = self.mapView.annotations.first(where: { $0 is UserPickedLocationAnnotation }) {
                    self.mapView.setCenter(annotation.coordinate, animated: false)
                }
            }) { (_) in
                self.reloadNearbyLocations(coordinate: coordinate)
            }
        } else {
            reloadNearbyLocations(coordinate: coordinate)
        }
    }
    
}

extension LocationPickerViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if searchResults == nil {
            return 2
        } else {
            if pickedSearchResult == nil {
                return 1
            } else {
                return 2
            }
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let results = searchResults {
            if section == 0 && pickedSearchResult != nil {
                return 1
            } else {
                return results.count
            }
        } else {
            if section == 0 {
                return 1
            } else {
                return nearbyLocations.count
            }
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.location, for: indexPath)!
        if let results = searchResults {
            if let result = pickedSearchResult, indexPath.section == 0 {
                cell.renderAsUserPickedLocation(address: result.name)
            } else {
                let location = results[indexPath.row]
                cell.render(location: location)
            }
        } else {
            if indexPath.section == 0 {
                if userDidDropThePin {
                    cell.renderAsUserPickedLocation(address: userPinnedLocationAddress)
                } else {
                    cell.renderAsUserLocation(accuracy: userLocationAccuracy)
                }
            } else {
                let location = nearbyLocations[indexPath.row]
                cell.render(location: location)
            }
        }
        return cell
    }
    
}

extension LocationPickerViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
    
}

extension LocationPickerViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
    
}

extension LocationPickerViewController {
    
    private func addUserPickedAnnotationAndRemoveThePlaceholder() {
        if !mapView.annotations.contains(where: { $0 is UserPickedLocationAnnotation }) {
            let point = CGPoint(x: mapView.frame.width / 2, y: (mapView.frame.height - tableViewMaskHeight) / 2)
            let coordinate = mapView.convert(point, toCoordinateFrom: view)
            let annotation = UserPickedLocationAnnotation(coordinate: coordinate)
            mapView.addAnnotation(annotation)
        }
        pinImageView.removeFromSuperview()
    }
    
    private func reloadNearbyLocations(coordinate: CLLocationCoordinate2D) {
        let willSearchCoordinateAtLeast100MetersAway = nearbyLocationsSearchCoordinate == nil
            || coordinate.distance(from: nearbyLocationsSearchCoordinate!) >= 100
        guard willSearchCoordinateAtLeast100MetersAway else {
            return
        }
        nearbyLocations = []
        tableView.reloadData()
        if tableView.tableFooterView == nil {
            nearbyLocationSearchingIndicator.startAnimating()
            tableView.tableFooterView = nearbyLocationSearchingIndicator
        }
        nearbyLocationsRequest?.cancel()
        nearbyLocationsRequest = FoursquareAPI.search(coordinate: coordinate, query: nil) { [weak self] (result) in
            guard let self = self else {
                return
            }
            switch result {
            case .success(let locations):
                self.nearbyLocationSearchingIndicator.stopAnimating()
                self.tableView.tableFooterView = nil
                self.nearbyLocations = locations
                self.tableView.reloadData()
                self.nearbyLocationsSearchCoordinate = coordinate
            case .failure:
                break
            }
        }
    }
    
    private func send(coordinate: CLLocationCoordinate2D, name: String?, address: String?, venueType: String?) {
        let location = Location(latitude: coordinate.latitude,
                                longitude: coordinate.longitude,
                                name: name,
                                address: address,
                                venueType: venueType)
        do {
            try input.send(location: location)
            navigationController?.popViewController(animated: true)
        } catch {
            reporter.report(error: error)
            showAutoHiddenHud(style: .error, text: R.string.localizable.chat_send_location_failed())
        }
    }
    
    private func reloadFirstCell() {
        let indexPath = IndexPath(row: 0, section: 0)
        tableView.reloadRows(at: [indexPath], with: .none)
    }
    
}
