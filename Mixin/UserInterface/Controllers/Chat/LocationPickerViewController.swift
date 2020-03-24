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
                textField.returnKeyType = .search
                textField.delegate = self
            }
        }
    }
    
    override var tableWrapperMaskHeight: CGFloat {
        didSet {
            pinImageViewIfLoaded?.center = pinImageViewCenter
            scrollToUserLocationButtonBottomConstraint.constant = tableWrapperMaskHeight + 20
            if let result = pickedSearchResult {
                mapView.setCenter(result.coordinate, animated: false)
            } else if let location = userPickedLocation {
                mapView.setCenter(location.coordinate, animated: false)
            } else if searchResults != nil {
                let diff = (tableWrapperMaskHeight - oldValue) / 2
                if diff != 0 {
                    let point = mapView.convert(mapView.centerCoordinate, toPointTo: view)
                    let newPoint = CGPoint(x: point.x, y: point.y + diff)
                    let coordinate = mapView.convert(newPoint, toCoordinateFrom: mapView)
                    mapView.setCenter(coordinate, animated: false)
                }
            }
        }
    }
    
    override var minTableWrapperMaskHeight: CGFloat {
        if let keyboardHeight = keyboardHeightIfShow {
            return keyboardHeight + 2 * tableView.rowHeight + tableView.sectionHeaderHeight
        } else {
            return super.minTableWrapperMaskHeight
        }
    }
    
    // meters according to https://developer.foursquare.com/docs/api/venues/search
    private let locationSearchRadius = 1000
    
    private let scrollToUserLocationButton = UIButton()
    private let pinImage = R.image.conversation.ic_annotation_pin()!
    private let nearbyLocationSearchingIndicator = ActivityIndicatorView()
    private let searchResultAnnotationReuseId = "search"
    private let locationManager = CLLocationManager()
    
    private lazy var geocoder = CLGeocoder()
    private lazy var searchView = R.nib.locationSearchView(owner: self)!
    private lazy var mapViewPanRecognizer = UIPanGestureRecognizer(target: self, action: #selector(dragMapAction(_:)))
    private lazy var mapViewPinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(dragMapAction(_:)))
    private lazy var pinImageView: UIImageView = {
        let view = UIImageView(image: pinImage)
        pinImageViewIfLoaded = view
        return view
    }()
    private lazy var noSearchResultsView: LocationSearchNoResultView = {
        let view = R.nib.locationSearchNoResultView(owner: nil)!
        noSearchResultsViewIfLoaded = view
        return view
    }()
    
    private weak var pinImageViewIfLoaded: UIImageView?
    private weak var noSearchResultsViewIfLoaded: LocationSearchNoResultView?
    
    private var input: ConversationInputViewController!
    private var scrollToUserLocationButtonBottomConstraint: NSLayoutConstraint!
    private var permissionWasAuthorized: Bool?
    
    private var userWillPickLocation = false
    private weak var userPickedLocation: UserPickedLocation?
    
    private var nearbyLocationsRequest: Request?
    private var nearbyLocationsSearchCoordinate: CLLocationCoordinate2D?
    private var nearbyLocations: [Location] = []
    
    private var isKeyboardAnimating = false
    private var keyboardHeightIfShow: CGFloat?
    
    private var isShowingSearchBar = false
    private var lastSearchRequest: Request?
    private var searchResults: [Location]?
    private var pickedSearchResult: Location?
    
    private var userLocationAccuracy: String {
        if let accuracy = mapView.userLocation.location?.horizontalAccuracy, accuracy > 0 {
            return "\(Int(accuracy))m"
        } else {
            return ">1km"
        }
    }
    
    private var pinImageViewCenter: CGPoint {
        CGPoint(x: view.bounds.midX, y: (view.bounds.height - tableWrapperMaskHeight) / 2 - pinImage.size.height / 2)
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
    
    private var isTableViewScrolling: Bool {
        tableView.isTracking || tableView.isDragging || tableView.isDecelerating
    }
    
    private var isAuthorized: Bool {
        let status = CLLocationManager.authorizationStatus()
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }
    
    private var sectionHeaderOnMaskTopContentOffset: CGPoint {
        CGPoint(x: 0, y: tableWrapperMaskHeight - minTableWrapperMaskHeight)
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
        mapView.register(SearchResultAnnotationView.self,
                         forAnnotationViewWithReuseIdentifier: searchResultAnnotationReuseId)
        for recognizer in [mapViewPanRecognizer, mapViewPinchRecognizer] {
            mapView.addGestureRecognizer(recognizer)
            recognizer.delegate = self
            if let popRecognizer = navigationController?.interactivePopGestureRecognizer {
                recognizer.require(toFail: popRecognizer)
            }
        }
        
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
        
        locationManager.delegate = self
        
        nearbyLocationSearchingIndicator.tintColor = R.color.text_desc()
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
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let tableContentHeight = minTableWrapperMaskHeight - tableView.sectionHeaderHeight - tableView.rowHeight
        nearbyLocationSearchingIndicator.indicatorCenterY = tableContentHeight / 2 - 20
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if CLLocationManager.authorizationStatus() == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let searchResults = searchResults {
            if indexPath.section == 0, let result = pickedSearchResult {
                send(location: result)
            } else {
                send(location: searchResults[indexPath.row])
            }
        } else {
            if indexPath.section == 0 {
                if let location = userPickedLocation {
                    send(coordinate: location.coordinate)
                } else if let location = mapView.userLocation.location {
                    send(coordinate: location.coordinate)
                } else {
                    alert(R.string.localizable.chat_user_location_undetermined())
                }
            } else {
                send(location: nearbyLocations[indexPath.row])
            }
        }
    }
    
    @IBAction func cancelSearchAction(_ sender: Any) {
        lastSearchRequest?.cancel()
        searchResults = nil
        pickedSearchResult = nil
        tableView.reloadData()
        let headerSize = CGSize(width: tableView.frame.width,
                                height: view.bounds.height - minTableWrapperMaskHeight)
        tableHeaderView.frame = CGRect(origin: .zero, size: headerSize)
        tableView.tableHeaderView = tableHeaderView
        tableView.tableFooterView = nil
        tableView.layoutIfNeeded()
        if let box = searchBoxView {
            box.isBusy = false
            box.textField.resignFirstResponder()
        }
        let annotations: [MKAnnotation]
        if mapView.annotations.contains(where: { $0 is MKUserLocation }) {
            annotations = mapView.annotations.filter({ !($0 is MKUserLocation) })
        } else {
            annotations = mapView.annotations.filter({ $0 is SearchResultAnnotation })
        }
        mapView.removeAnnotations(annotations)
        UIView.animate(withDuration: 0.3, animations: {
            self.searchView.alpha = 0
            self.tableWrapperMaskHeight = self.minTableWrapperMaskHeight
            self.tableView.setContentOffset(.zero, animated: true)
            if !self.isAuthorized {
                self.putUserPickedAnnotation()
            }
            let coordinate = self.userPickedLocation?.coordinate
                ?? self.mapView.userLocation.location?.coordinate
            if let coor = coordinate {
                self.mapView.setCenter(coor, animated: true)
            }
        }) { (_) in
            if self.isAuthorized {
                self.mapView.setUserTrackingMode(.follow, animated: true)
            }
            self.searchBoxView?.textField.text = nil
            let coordinate = self.userPickedLocation?.coordinate
                ?? self.mapView.userLocation.location?.coordinate
            if let coor = coordinate {
                self.reloadNearbyLocations(coordinate: coor)
            }
        }
        isShowingSearchBar = false
    }
    
    @objc private func scrollToUserLocationAction(_ sender: Any) {
        if searchResults != nil {
            mapView.setCenter(mapView.userLocation.coordinate, animated: true)
        } else {
            if isAuthorized {
                mapView.setUserTrackingMode(.follow, animated: true)
            }
            if let location = userPickedLocation {
                mapView.removeAnnotations([location])
                if let location = mapView.userLocation.location {
                    reloadNearbyLocations(coordinate: location.coordinate)
                } else {
                    tableView.reloadData()
                }
                tableView.layoutIfNeeded()
                tableView.setContentOffset(sectionHeaderOnMaskTopContentOffset, animated: true)
            }
        }
    }
    
    @objc private func dragMapAction(_ recognizer: UIPanGestureRecognizer) {
        guard searchResults == nil, !isShowingSearchBar else {
            return
        }
        guard recognizer.state == .began else {
            return
        }
        userWillPickLocation = true
        mapView.userTrackingMode = .none
        if let location = userPickedLocation {
            mapView.removeAnnotation(location)
        }
        if pinImageView.superview == nil {
            pinImageView.center = pinImageViewCenter
            view.addSubview(pinImageView)
        }
        geocoder.cancelGeocode()
        userPickedLocation = nil
        reloadFirstCell()
        tableView.setContentOffset(tableView.contentOffset, animated: false)
        tableView.setContentOffset(sectionHeaderOnMaskTopContentOffset, animated: true)
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
        updateNoSearchResultsViewLayout(isKeyboardVisible: !keyboardWillBeInvisible)
        let headerSize = CGSize(width: tableView.bounds.width,
                                height: view.bounds.height - minTableWrapperMaskHeight)
        if tableHeaderView.frame.height != headerSize.height {
            tableHeaderView.frame = CGRect(origin: .zero, size: headerSize)
            tableView.tableHeaderView = tableHeaderView
        }
        if !keyboardWillBeInvisible {
            tableWrapperMaskHeight = minTableWrapperMaskHeight
        }
        tableView.contentOffset = sectionHeaderOnMaskTopContentOffset
        view.layoutIfNeeded()
    }
    
    @objc private func keyboardDidEndAnimating(_ notification: Notification) {
        isKeyboardAnimating = false
    }
    
    @objc private func search(_ sender: UITextField) {
        lastSearchRequest?.cancel()
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        guard let keyword = trimmedKeyword else {
            searchBoxView?.isBusy = false
            searchResults = nil
            tableView.reloadData()
            tableView.tableFooterView = nil
            return
        }
        perform(#selector(requestSearch(keyword:)), with: keyword, afterDelay: 1)
    }
    
    @objc private func requestSearch(keyword: String) {
        searchBoxView?.isBusy = true
        let coordinate: CLLocationCoordinate2D
        if let annotation = userPickedLocation {
            coordinate = annotation.coordinate
        } else if let userLocation = mapView.userLocation.location {
            coordinate = userLocation.coordinate
        } else {
            coordinate = mapView.centerCoordinate
        }
        lastSearchRequest = FoursquareAPI.search(coordinate: coordinate, radius: locationSearchRadius, query: keyword, completion: { [weak self] (result) in
            guard let self = self, self.isShowingSearchBar else {
                return
            }
            let locations: [Location]
            switch result {
            case .success(let resultLocations):
                locations = resultLocations
            case .failure(let error):
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
                    return
                } else {
                    locations = []
                }
            }
            self.pickedSearchResult = nil
            self.searchResults = locations
            self.tableWrapperMaskHeight = self.minTableWrapperMaskHeight
            self.tableView.contentOffset = .zero
            self.tableView.reloadData()
            if locations.isEmpty {
                self.noSearchResultsView.label.text = R.string.localizable.chat_location_search_no_result(keyword)
                self.noSearchResultsView.frame.size = CGSize(width: self.view.bounds.width, height: self.tableWrapperMaskHeight)
                self.tableView.tableFooterView = self.noSearchResultsView
                self.updateNoSearchResultsViewLayout(isKeyboardVisible: self.keyboardHeightIfShow != nil)
            } else {
                self.tableView.tableFooterView = nil
            }
            self.searchBoxView?.isBusy = false
            let annotations = self.mapView.annotations.filter({ !($0 is MKUserLocation) })
            self.mapView.removeAnnotations(annotations)
            let resultAnnotations = locations.map(SearchResultAnnotation.init)
            self.mapView.addAnnotations(resultAnnotations)
            self.mapView.showAnnotations(resultAnnotations, animated: true)
        })
    }
    
}

extension LocationPickerViewController: ContainerViewControllerDelegate {
    
    func barRightButtonTappedAction() {
        if pinImageView.superview != nil {
            putUserPickedAnnotation()
        }
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
        isShowingSearchBar = true
        searchBoxView?.textField.becomeFirstResponder()
    }
    
    func imageBarRightButton() -> UIImage? {
        R.image.ic_title_search()
    }
    
}

extension LocationPickerViewController: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if !locations.isEmpty, !mapView.showsUserLocation {
            mapView.showsUserLocation = true
            if searchResults == nil, userPickedLocation == nil {
                scrollToUserLocationAction(self)
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch CLLocationManager.authorizationStatus() {
        case .authorizedAlways, .authorizedWhenInUse:
            if let wasAuthorized = permissionWasAuthorized, !wasAuthorized {
                if let location = userPickedLocation {
                    mapView.removeAnnotation(location)
                }
                userPickedLocation = nil
            }
            scrollToUserLocationButton.isHidden = false
            manager.startUpdatingLocation()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            fallthrough
        @unknown default:
            mapView.showsUserLocation = false
            manager.stopUpdatingLocation()
            scrollToUserLocationButton.isHidden = true
            if userPickedLocation == nil {
                putUserPickedAnnotation()
            }
        }
        permissionWasAuthorized = self.isAuthorized
    }
    
}

extension LocationPickerViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        let shouldPutUserPickedAnnotation = !isTableViewScrolling
            && userWillPickLocation
            && searchResults == nil
            && !isKeyboardAnimating
            && !isShowingSearchBar
        if shouldPutUserPickedAnnotation {
            putUserPickedAnnotation()
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is UserPickedLocation {
            return mapView.dequeueReusableAnnotationView(withIdentifier: pinAnnotationReuseId, for: annotation)
        } else if annotation is SearchResultAnnotation {
            return mapView.dequeueReusableAnnotationView(withIdentifier: searchResultAnnotationReuseId, for: annotation)
        } else {
            return nil
        }
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let picked = view.annotation as? SearchResultAnnotation else {
            return
        }
        mapView.userTrackingMode = .none
        self.pickedSearchResult = picked.location
        tableView.reloadData()
        tableView.layoutIfNeeded() // setContentOffset: is not working without layoutIfNeeded
        UIView.animate(withDuration: 0.3) {
            self.tableWrapperMaskHeight = self.minTableWrapperMaskHeight
            self.tableView.contentOffset = .zero
            self.mapView.setCenter(picked.coordinate, animated: false)
        }
    }
    
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        if !userWillPickLocation && userPickedLocation == nil {
            reloadNearbyLocations(coordinate: userLocation.coordinate)
            reloadFirstCell()
        }
    }
    
}

extension LocationPickerViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if let searchResults = searchResults {
            if searchResults.isEmpty {
                return 0
            } else if pickedSearchResult == nil {
                return 1
            } else {
                return 2
            }
        } else {
            return 2
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
        configure(cell: cell, at: indexPath)
        return cell
    }
    
}

extension LocationPickerViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        switch gestureRecognizer {
        case mapViewPanRecognizer:
            return otherGestureRecognizer != mapViewPinchRecognizer
        case mapViewPinchRecognizer:
            return otherGestureRecognizer != mapViewPanRecognizer
        default:
            return true
        }
    }
    
}

extension LocationPickerViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
    
}

extension LocationPickerViewController {
    
    private func configure(cell: LocationCell, at indexPath: IndexPath) {
        if let results = searchResults {
            if let result = pickedSearchResult, indexPath.section == 0 {
                cell.renderAsUserPickedLocation(address: result.name)
            } else {
                let location = results[indexPath.row]
                cell.render(location: location)
            }
        } else {
            if indexPath.section == 0 {
                if userWillPickLocation {
                    cell.renderAsUserPickedLocation(address: nil)
                } else if let location = userPickedLocation {
                    cell.renderAsUserPickedLocation(address: location.address)
                } else {
                    cell.renderAsUserLocation(accuracy: userLocationAccuracy)
                }
            } else {
                let location = nearbyLocations[indexPath.row]
                cell.render(location: location)
            }
        }
    }
    
    private func putUserPickedAnnotation() {
        guard userPickedLocation == nil else {
            return
        }
        let point = CGPoint(x: mapView.frame.width / 2, y: (mapView.frame.height - tableWrapperMaskHeight) / 2)
        let coordinate = mapView.convert(point, toCoordinateFrom: view)
        let userPickedLocation = UserPickedLocation(coordinate: coordinate)
        mapView.addAnnotation(userPickedLocation)
        self.userPickedLocation = userPickedLocation
        DispatchQueue.main.async(execute: pinImageView.removeFromSuperview)
        
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        geocoder.reverseGeocodeLocation(location) { [weak self] (placemarks, error) in
            guard let self = self, self.userPickedLocation == userPickedLocation else {
                return
            }
            if let address = placemarks?.first?.postalAddress {
                userPickedLocation.address = address.street
            } else {
                userPickedLocation.address = ""
            }
            self.reloadFirstCell()
        }
        reloadNearbyLocations(coordinate: coordinate)
        userWillPickLocation = false
    }
    
    private func reloadNearbyLocations(coordinate: CLLocationCoordinate2D) {
        let shouldReload: Bool
        if let previous = nearbyLocationsSearchCoordinate {
            shouldReload = coordinate.distance(from: previous) >= 100
        } else {
            shouldReload = nearbyLocationsRequest == nil
        }
        guard shouldReload else {
            return
        }
        if tableView.tableFooterView == nil {
            nearbyLocationSearchingIndicator.frame.size.height = tableWrapperMaskHeight
                - tableView.sectionHeaderHeight
                - tableView.rowHeight
            nearbyLocationSearchingIndicator.startAnimating()
            tableView.tableFooterView = nearbyLocationSearchingIndicator
        }
        nearbyLocations = []
        tableView.reloadData()
        nearbyLocationsRequest?.cancel()
        nearbyLocationsRequest = FoursquareAPI.search(coordinate: coordinate, radius: nil, query: nil) { [weak self] (result) in
            guard let self = self else {
                return
            }
            self.nearbyLocationsRequest = nil
            switch result {
            case .success(let locations):
                self.nearbyLocationSearchingIndicator.stopAnimating()
                self.tableView.tableFooterView = nil
                self.nearbyLocations = locations
                self.tableView.reloadData()
                self.tableView.layoutIfNeeded()
                self.tableView.setContentOffset(self.sectionHeaderOnMaskTopContentOffset, animated: false)
                self.nearbyLocationsSearchCoordinate = coordinate
            case .failure:
                self.nearbyLocationsSearchCoordinate = nil
            }
        }
    }
    
    private func send(location: Location) {
        do {
            try input.send(location: location)
            navigationController?.popViewController(animated: true)
        } catch {
            reporter.report(error: error)
            showAutoHiddenHud(style: .error, text: R.string.localizable.chat_send_location_failed())
        }
    }
    
    private func send(coordinate: CLLocationCoordinate2D) {
        let location = Location(latitude: coordinate.latitude,
                                longitude: coordinate.longitude,
                                name: nil,
                                address: nil,
                                venueType: nil)
        send(location: location)
    }
    
    private func reloadFirstCell() {
        let indexPath = IndexPath(row: 0, section: 0)
        guard let cell = tableView.cellForRow(at: indexPath) as? LocationCell else {
            return
        }
        configure(cell: cell, at: indexPath)
    }
    
    private func updateNoSearchResultsViewLayout(isKeyboardVisible: Bool) {
        guard let view = noSearchResultsViewIfLoaded else {
            return
        }
        if isKeyboardVisible {
            view.labelTopConstraint.priority = .defaultHigh
            view.labelCenterYConstraint.priority = .defaultLow
        } else {
            view.labelTopConstraint.priority = .defaultLow
            view.labelCenterYConstraint.priority = .defaultHigh
        }
    }
    
}
