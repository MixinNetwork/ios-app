import UIKit
import AVFoundation
import MixinServices

class PlaylistViewController: ResizablePopupViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var nowPlayingView: UIView!
    @IBOutlet weak var nowPlayingInfoView: MusicInfoView!
    
    @IBOutlet weak var timeControlStackView: UIStackView!
    @IBOutlet weak var playedTimeLabel: UILabel!
    @IBOutlet weak var slider: PlaylistSlider!
    @IBOutlet weak var remainingTimeLabel: UILabel!
    
    @IBOutlet weak var controlPanelStackView: UIStackView!
    @IBOutlet weak var repeatModeButton: BouncingButton!
    @IBOutlet weak var previousTrackButton: BouncingButton!
    @IBOutlet weak var playButton: BouncingButton!
    @IBOutlet weak var nextTrackButton: BouncingButton!
    @IBOutlet weak var playbackRateButton: BouncingButton!
    
    @IBOutlet weak var controlPanelBottomConstraint: NSLayoutConstraint!
    
    override var resizableScrollView: UIScrollView? {
        tableView
    }
    
    private let cellReuseId = "item"
    private let manager = PlaylistManager.shared
    private let loadMoreThreshold = 5
    
    private var resizeRecognizerDelegate: GestureCoordinator!
    
    private var isSeeking = false
    private var sliderObserver: Any?
    private var timeLabelObserver: Any?
    
    deinit {
        removeTimeObservers()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        modalPresentationStyle = .custom
        transitioningDelegate = PopupPresentationManager.shared
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.layer.cornerRadius = 13
        view.addGestureRecognizer(resizeRecognizer)
        
        resizeRecognizerDelegate = GestureCoordinator(scrollView: resizableScrollView)
        resizeRecognizerDelegate.ignoreGestureRecognizerView = nowPlayingView
        resizeRecognizer.delegate = resizeRecognizerDelegate
        
        updateControlPanelBottomMargin()
        
        tableView.register(PlaylistItemCell.self, forCellReuseIdentifier: cellReuseId)
        tableView.dataSource = self
        tableView.delegate = self
        
        nowPlayingView.layer.shadowColor = UIColor.black.cgColor
        nowPlayingView.layer.shadowOpacity = 0.08
        nowPlayingView.layer.shadowOffset = CGSize(width: 0, height: 1)
        nowPlayingView.layer.shadowRadius = 15
        
        let nowPlayingImageMaskView = UIView()
        nowPlayingImageMaskView.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        nowPlayingImageMaskView.layer.cornerRadius = nowPlayingInfoView.imageView.layer.cornerRadius
        nowPlayingImageMaskView.clipsToBounds = true
        nowPlayingView.addSubview(nowPlayingImageMaskView)
        nowPlayingImageMaskView.snp.makeConstraints { (make) in
            make.edges.equalTo(nowPlayingInfoView.imageView)
        }
        
        for label in [playedTimeLabel!, remainingTimeLabel!] {
            label.font = UIFontMetrics.default.scaledFont(for: .monospacedDigitSystemFont(ofSize: 14, weight: .regular))
            label.adjustsFontForContentSizeCategory = true
        }
        
        switch ScreenWidth.current {
        case .short:
            controlPanelStackView.spacing = 16
        case .medium:
            controlPanelStackView.spacing = 32
        case .long:
            controlPanelStackView.spacing = 48
        }
        if let item = manager.playingItem {
            updateNowPlayingView(with: item)
        }
        switch manager.status {
        case .playing:
            playButton.setImage(R.image.playlist.ic_pause(), for: .normal)
        case .paused:
            playButton.setImage(R.image.playlist.ic_play(), for: .normal)
        case .stopped:
            playButton.setImage(R.image.playlist.ic_play(), for: .normal)
        }
        playButton.isEnabled = !manager.items.isEmpty
        updateRepeatModeButton()
        updatePlaybackRateButton()
        
        manager.delegate = self
        addTimeObservers()
        
        let center = NotificationCenter.default
        center.addObserver(self,
                           selector: #selector(updateCell(_:)),
                           name: PlaylistItem.beginLoadingAssetNotification,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(updateCell(_:)),
                           name: PlaylistItem.finishLoadingAssetNotification,
                           object: nil)
        center.addObserver(self,
                           selector: #selector(applicationDidEnterBackground(_:)),
                           name: UIApplication.didEnterBackgroundNotification,
                           object: nil)
    }
    
    override func preferredContentHeight(forSize size: Size) -> CGFloat {
        let window = AppDelegate.current.mainWindow
        switch size {
        case .expanded, .unavailable:
            return window.bounds.height - window.safeAreaInsets.top
        case .compressed:
            return floor(window.bounds.height / 3 * 2)
        }
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateControlPanelBottomMargin()
    }
    
}

// MARK: - Actions
extension PlaylistViewController {
    
    @IBAction func stop(_ sender: Any) {
        let alert = UIAlertController(title: R.string.localizable.playlist_stop_confirmation(), message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: R.string.localizable.playlist_stop(), style: .default, handler: { (_) in
            self.manager.stop()
            self.dismiss(animated: true) {
                self.manager.removeAllItems()
            }
        }))
        alert.addAction(UIAlertAction(title: R.string.localizable.dialog_button_cancel(), style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func hide(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func beginScrubbingAction(_ sender: Any) {
        removeTimeObservers()
    }
    
    @IBAction func scrubAction(_ sender: Any) {
        guard let item = manager.player.currentItem else {
            return
        }
        let duration = CMTimeGetSeconds(item.duration)
        guard duration.isFinite else {
            return
        }
        let time = CMTime(seconds: Double(duration) * slider.percentage,
                          preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        updateTimeLabel(time: time, duration: item.duration)
    }
    
    @IBAction func endScrubbingAction(_ sender: Any) {
        manager.seek(to: slider.percentage) { [weak self] (finished) in
            guard finished, let self = self else {
                return
            }
            guard self.sliderObserver == nil && self.timeLabelObserver == nil else {
                return
            }
            self.addTimeObservers()
        }
    }
    
    @IBAction func switchRepeatMode(_ sender: Any) {
        manager.repeatMode = manager.repeatMode.next
        updateRepeatModeButton()
        previousTrackButton.isEnabled = manager.hasPreviousItem
        nextTrackButton.isEnabled = manager.hasNextItem
    }
    
    @IBAction func playPrevious(_ sender: Any) {
        manager.playPreviousItem()
    }
    
    @IBAction func play(_ sender: Any) {
        switch manager.status {
        case .playing:
            playButton.setImage(R.image.playlist.ic_play(), for: .normal)
        case .paused:
            if manager.playingItem != nil {
                playButton.setImage(R.image.playlist.ic_pause(), for: .normal)
            }
        case .stopped:
            break
        }
        manager.playOrPauseCurrentItem()
    }
    
    @IBAction func playNext(_ sender: Any) {
        manager.playNextItem()
    }
    
    @IBAction func switchPlaybackRate(_ sender: Any) {
        manager.playbackRate = manager.playbackRate.next
        updatePlaybackRateButton()
    }
    
}

// MARK: - UITableViewDataSource
extension PlaylistViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        manager.items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseId) as! PlaylistItemCell
        let item = manager.items[indexPath.row]
        cell.id = item.id
        cell.infoView.imageView.image = item.metadata.image
        cell.infoView.titleLabel.text = item.metadata.title
        cell.infoView.subtitleLabel.text = item.metadata.subtitle
        if item.asset == nil {
            cell.fileStatus = item.isLoadingAsset ? .downloading : .pending
        } else {
            cell.fileStatus = .ready
        }
        return cell
    }
    
}

// MARK: - UITableViewDelegate
extension PlaylistViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? PlaylistItemCell, let id = cell.id else {
            return
        }
        manager.register(cell: cell, for: id)
    }
    
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? PlaylistItemCell, let id = cell.id else {
            return
        }
        manager.unregister(cell: cell, for: id)
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = manager.items[indexPath.row]
        if item.asset == nil {
            item.downloadAttachment()
        } else {
            manager.playOrPauseLoadedItem(at: indexPath.row)
        }
    }
    
}

// MARK: - PlaylistManagerDelegate
extension PlaylistViewController: PlaylistManagerDelegate {
    
    func playlistManager(_ manager: PlaylistManager, willPlay item: PlaylistItem) {
        playButton.setImage(R.image.playlist.ic_pause(), for: .normal)
        updateNowPlayingView(with: item)
    }
    
    func playlistManagerDidPause(_ manager: PlaylistManager) {
        playButton.setImage(R.image.playlist.ic_play(), for: .normal)
    }
    
    func playlistManager(_ manager: PlaylistManager, didLoadEarlierItems items: [PlaylistItem]) {
        let indexPaths = (0..<items.count).map {
            IndexPath(row: $0, section: 0)
        }
        tableView.insertRows(at: indexPaths, with: .none)
        previousTrackButton.isEnabled = manager.hasPreviousItem
    }
    
    func playlistManager(_ manager: PlaylistManager, didLoadLaterItems items: [PlaylistItem]) {
        let range = (manager.items.count - items.count)..<manager.items.count
        let indexPaths = range.map {
            IndexPath(row: $0, section: 0)
        }
        tableView.insertRows(at: indexPaths, with: .none)
        nextTrackButton.isEnabled = manager.hasNextItem
    }
    
    func playlistManagerDidEnd(_ manager: PlaylistManager) {
        playButton.setImage(R.image.playlist.ic_play(), for: .normal)
        updateNowPlayingView(with: nil)
    }
    
    func playlistManager(_ manager: PlaylistManager, didRemoveItemAt index: Int) {
        let indexPath = IndexPath(row: index, section: 0)
        tableView.deleteRows(at: [indexPath], with: .automatic)
        playButton.isEnabled = !manager.items.isEmpty
        previousTrackButton.isEnabled = manager.hasPreviousItem
        nextTrackButton.isEnabled = manager.hasNextItem
    }
    
    func playlistManagerDidRemoveAll(_ manager: PlaylistManager) {
        tableView.reloadData()
        playButton.isEnabled = !manager.items.isEmpty
        previousTrackButton.isEnabled = false
        nextTrackButton.isEnabled = false
    }
    
}

// MARK: - Callbacks
extension PlaylistViewController {
    
    @objc private func applicationDidEnterBackground(_ notification: Notification) {
        dismiss(animated: false, completion: nil)
    }
    
    @objc private func updateCell(_ notification: Notification) {
        guard let item = notification.object as? PlaylistItem else {
            return
        }
        guard let row = manager.items.firstIndex(where: { $0.id == item.id }) else {
            return
        }
        tableView.reloadRows(at: [IndexPath(row: row, section: 0)], with: .none)
    }
    
}

// MARK: - GestureCoordinator
extension PlaylistViewController {
    
    private final class GestureCoordinator: PopupResizeGestureCoordinator {
        
        weak var ignoreGestureRecognizerView: UIView?
        
        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let view = ignoreGestureRecognizerView else {
                return super.gestureRecognizerShouldBegin(gestureRecognizer)
            }
            let location = gestureRecognizer.location(in: view)
            if view.bounds.contains(location) {
                return false
            } else {
                return super.gestureRecognizerShouldBegin(gestureRecognizer)
            }
        }
        
    }
    
}

// MARK: - Time Observation
extension PlaylistViewController {
    
    private func addTimeObservers() {
        let player = manager.player
        let timescale = CMTimeScale(600)
        
        let sliderInterval = CMTime(seconds: 0.1, preferredTimescale: timescale)
        sliderObserver = player.addPeriodicTimeObserver(forInterval: sliderInterval, queue: .main) { [weak self] (time) in
            guard let self = self else {
                return
            }
            guard let item = self.manager.playingItem else {
                return
            }
            self.updateSliderPosition(time: time, duration: item.metadata.duration)
        }
        
        let timeLabelInterval = CMTime(seconds: 1, preferredTimescale: timescale)
        timeLabelObserver = player.addPeriodicTimeObserver(forInterval: timeLabelInterval, queue: .main) { [weak self] (time) in
            guard let self = self else {
                return
            }
            guard let item = self.manager.playingItem else {
                return
            }
            self.updateTimeLabel(time: time, duration: item.metadata.duration)
        }
    }
    
    private func removeTimeObservers() {
        [sliderObserver, timeLabelObserver]
            .compactMap { $0 }
            .forEach(manager.player.removeTimeObserver)
        sliderObserver = nil
        timeLabelObserver = nil
    }
    
}

// MARK: - Interface
extension PlaylistViewController {
    
    private func updateControlPanelBottomMargin() {
        if view.safeAreaInsets.bottom > 6 {
            controlPanelBottomConstraint.constant = 21
        } else {
            controlPanelBottomConstraint.constant = 27
        }
    }
    
    private func updateSliderPosition(time: CMTime, duration: CMTime) {
        guard duration.isValid else {
            return
        }
        let duration = CMTimeGetSeconds(duration)
        guard duration.isFinite else {
            return
        }
        let time = CMTimeGetSeconds(time)
        let maxValue = slider.maximumValue
        let minValue = slider.minimumValue
        let sliderValue = (maxValue - minValue) * Float(time / duration) + minValue
        slider.setValue(sliderValue, animated: false)
    }
    
    private func updateTimeLabel(time: CMTime, duration: CMTime) {
        guard duration.isValid else {
            return
        }
        let duration = CMTimeGetSeconds(duration)
        guard duration.isFinite else {
            return
        }
        let time = CMTimeGetSeconds(time)
        guard time.isFinite && !time.isNaN else {
            return
        }
        playedTimeLabel.text = mediaDurationFormatter.string(from: time)
        if let remaining = mediaDurationFormatter.string(from: duration - time) {
            remainingTimeLabel.text = "-" + remaining
        } else {
            remainingTimeLabel.text = nil
        }
    }
    
    private func updateNowPlayingView(with item: PlaylistItem?) {
        if let item = item {
            slider.isEnabled = true
            let player = manager.player
            updateSliderPosition(time: player.currentTime(), duration: item.metadata.duration)
            updateTimeLabel(time: player.currentTime(), duration: item.metadata.duration)
            nowPlayingInfoView.imageView.image = item.metadata.image
            nowPlayingInfoView.titleLabel.text = item.metadata.title
            nowPlayingInfoView.subtitleLabel.text = item.metadata.subtitle
            previousTrackButton.isEnabled = manager.hasPreviousItem
            nextTrackButton.isEnabled = manager.hasNextItem
        } else {
            slider.setValue(slider.minimumValue, animated: false)
            slider.isEnabled = false
            let zeroTime = mediaDurationFormatter.string(from: 0)
            playedTimeLabel.text = zeroTime
            remainingTimeLabel.text = zeroTime
            nowPlayingInfoView.imageView.image = nil
            nowPlayingInfoView.titleLabel.text = R.string.localizable.playlist_not_playing()
            nowPlayingInfoView.subtitleLabel.text = nil
            previousTrackButton.isEnabled = false
            nextTrackButton.isEnabled = false
        }
    }
    
    private func updateRepeatModeButton() {
        switch manager.repeatMode {
        case .repeatList:
            repeatModeButton.setImage(R.image.playlist.ic_repeat_list(), for: .normal)
        case .repeatSingle:
            repeatModeButton.setImage(R.image.playlist.ic_repeat_single(), for: .normal)
        case .shuffle:
            repeatModeButton.setImage(R.image.playlist.ic_shuffle(), for: .normal)
        }
    }
    
    private func updatePlaybackRateButton() {
        switch manager.playbackRate {
        case .normal:
            playbackRateButton.setImage(R.image.playlist.ic_rate_normal(), for: .normal)
            playbackRateButton.tintColor = R.color.text_accessory()
        case .faster:
            playbackRateButton.setImage(R.image.playlist.ic_rate_faster(), for: .normal)
            playbackRateButton.tintColor = R.color.theme()
        case .fastest:
            playbackRateButton.setImage(R.image.playlist.ic_rate_fastest(), for: .normal)
            playbackRateButton.tintColor = R.color.theme()
        }
    }
    
}
