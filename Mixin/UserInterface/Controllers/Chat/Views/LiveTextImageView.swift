import VisionKit
import MixinServices
import SDWebImage

@available(iOS 16.0, *)
class LiveTextImageView: SDAnimatedImageView {
    
    static var isImageAnalyzerSupported: Bool {
        ImageAnalyzer.isSupported
    }
    
    private let analyzer = ImageAnalyzer()
    private let interaction = ImageAnalysisInteraction()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addInteraction(interaction)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func startAnalysis() {
        interaction.analysis = nil
        interaction.preferredInteractionTypes = []
        guard let image = image else {
            return
        }
        Task {
            let configuration = ImageAnalyzer.Configuration([.text])
            do {
                let analysis = try await analyzer.analyze(image, configuration: configuration)
                if image == self.image {
                    interaction.analysis = analysis
                    interaction.preferredInteractionTypes = .automatic
                }
            } catch {
                Logger.general.error(category: "LiveTextImageView", message: "Error in live text analysis: \(error.localizedDescription)")
            }
        }
    }
    
}

//MARK: - UIImageView Live Text
extension UIImageView {
    
    func startImageLiveTextAnalysisIfNeeded() {
        guard #available(iOS 16, *), let liveTextImageView = self as? LiveTextImageView else {
            return
        }
        liveTextImageView.startAnalysis()
    }
    
}
