import UIKit
import MapKit

class LocationMessageCell: ImageMessageCell {
    
    private let mapImageView = UIImageView()
    private let annotationView = UIImageView(image: R.image.conversation.ic_annotation_pin())
    
    private lazy var informationView: LocationInformationView = {
        let view = LocationInformationView()
        informationViewIfLoaded = view
        return view
    }()
    
    private var informationViewIfLoaded: LocationInformationView?
    private var snapshotter: MKMapSnapshotter?
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle {
            reloadMapImage()
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        mapImageView.image = nil
        snapshotter?.cancel()
        snapshotter = nil
        annotationView.isHidden = true
    }
    
    override func render(viewModel: MessageViewModel) {
        super.render(viewModel: viewModel)
        if let viewModel = viewModel as? LocationMessageViewModel {
            if viewModel.quotedMessageViewModel == nil {
                maskingView.frame = messageContentView.bounds
                mapImageView.frame = viewModel.photoFrame
                maskingView.layer.cornerRadius = 0
                if backgroundImageView.superview != nil {
                    backgroundImageView.removeFromSuperview()
                }
                if maskingView.layer.mask == nil {
                    maskingView.layer.mask = backgroundImageView.layer
                }
            } else {
                maskingView.frame = viewModel.photoFrame
                mapImageView.frame = maskingView.bounds
                if maskingView.layer.mask == backgroundImageView.layer {
                    maskingView.layer.mask = nil
                }
                if backgroundImageView.superview == nil {
                    messageContentView.insertSubview(backgroundImageView, at: 0)
                }
                maskingView.layer.cornerRadius = Self.quotingPhotoCornerRadius
            }
            if let frame = viewModel.informationFrame {
                informationView.frame = frame
                informationView.nameLabel.text = viewModel.message.location?.name
                informationView.addressLabel.text = viewModel.message.location?.address
                informationView.contentLeadingConstraint.constant = viewModel.labelsLeadingConstant
                informationView.trailingPlaceholderWidthConstraint.constant = viewModel.trailingInfoBackgroundFrame.width + 6
                if informationView.superview == nil {
                    maskingView.insertSubview(informationView, aboveSubview: mapImageView)
                }
            } else {
                informationViewIfLoaded?.removeFromSuperview()
            }
            if let informationFrame = informationViewIfLoaded?.frame {
                selectedOverlapView.frame = mapImageView.frame.union(informationFrame)
            } else {
                selectedOverlapView.frame = mapImageView.frame
            }
            if viewModel.hasAddress {
                trailingInfoBackgroundView.isHidden = true
            } else {
                trailingInfoBackgroundView.frame = viewModel.trailingInfoBackgroundFrame
                trailingInfoBackgroundView.isHidden = false
            }
            reloadMapImage()
        }
    }
    
    override func prepare() {
        messageContentView.addSubview(maskingView)
        mapImageView.backgroundColor = .lightGray
        maskingView.addSubview(mapImageView)
        updateAppearance(highlight: false, animated: false)
        annotationView.isHidden = true
        mapImageView.addSubview(annotationView)
        messageContentView.addSubview(trailingInfoBackgroundView)
        super.prepare()
        maskingView.addSubview(selectedOverlapView)
        backgroundImageView.removeFromSuperview()
        maskingView.layer.mask = backgroundImageView.layer
        maskingView.clipsToBounds = true
        forwarderImageView.alpha = 0.9
        encryptedImageView.alpha = 0.9
        statusImageView.alpha = 0.9
    }
    
    private func reloadMapImage() {
        guard let viewModel = viewModel as? LocationMessageViewModel else {
            return
        }
        if let (image, center) = viewModel.cachedSnapshot[.current] {
            mapImageView.image = image
            annotationView.center = center
            annotationView.isHidden = false
        } else if let coordinate = viewModel.message.location?.coordinate {
            mapImageView.image = R.image.conversation.bg_message_location()
            let options = MKMapSnapshotter.Options()
            options.region = MKCoordinateRegion(center: coordinate,
                                                latitudinalMeters: 1000,
                                                longitudinalMeters: 1000)
            options.size = viewModel.photoFrame.size
            if #available(iOS 13.0, *) {
                options.traitCollection = traitCollection
            } else {
                options.scale = UIScreen.main.scale
            }
            let snapshotter = MKMapSnapshotter(options: options)
            snapshotter.start { [weak self] (snapshot, error) in
                guard let self = self, let snapshot = snapshot else {
                    return
                }
                self.mapImageView.image = snapshot.image
                let center = snapshot.point(for: coordinate)
                self.annotationView.isHidden = false
                self.annotationView.center = center
                viewModel.cachedSnapshot[.current] = (snapshot.image, center)
            }
            self.snapshotter = snapshotter
        } else {
            mapImageView.image = R.image.conversation.bg_message_location()
            annotationView.isHidden = true
        }
    }
    
}
