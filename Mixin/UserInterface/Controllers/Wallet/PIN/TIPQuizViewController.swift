import UIKit
import SafariServices

final class TIPQuizViewController: UIViewController {
    
    private enum Section: Int, CaseIterable {
        case question
        case answer
    }
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var checkAnswerButton: UIButton!
    @IBOutlet weak var explainPINButton: UIButton!
    
    private let pin: String
    
    init(pin: String) {
        self.pin = pin
        let nib = R.nib.tipQuizView
        super.init(nibName: nib.name, bundle: nib.bundle)
    }
    
    required init?(coder: NSCoder) {
        fatalError("Storyboard is not supported")
    }
    
    private var selectedAnswer: TIPQuizAnswer? {
        didSet {
            checkAnswerButton.isEnabled = selectedAnswer != nil
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.rightBarButtonItem = .customerService(
            target: self,
            action: #selector(presentCustomerService(_:))
        )
        
        collectionView.register(R.nib.tipQuizQuestionCell)
        collectionView.register(R.nib.tipQuizAnswerCell)
        collectionView.collectionViewLayout = UICollectionViewCompositionalLayout { sectionIndex, _ in
            switch Section(rawValue: sectionIndex)! {
            case .question:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(326))
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
                return section
            case .answer:
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .fractionalHeight(1))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(54))
                let group: NSCollectionLayoutGroup = .horizontal(layoutSize: groupSize, subitems: [item])
                let section = NSCollectionLayoutSection(group: group)
                section.interGroupSpacing = 10
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
                return section
            }
        }
        collectionView.dataSource = self
        collectionView.delegate = self
        
        checkAnswerButton.configuration = {
            var config: UIButton.Configuration = .filled()
            config.baseBackgroundColor = R.color.background_tinted()
            config.baseForegroundColor = .white
            config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 0, bottom: 11, trailing: 0)
            config.cornerStyle = .capsule
            
            var attributes = AttributeContainer()
            attributes.font = UIFontMetrics.default.scaledFont(
                for: .systemFont(ofSize: 16, weight: .medium)
            )
            config.attributedTitle = AttributedString(
                R.string.localizable.check_answer(),
                attributes: attributes
            )
            
            return config
        }()
        checkAnswerButton.titleLabel?.adjustsFontForContentSizeCategory = true
        
        explainPINButton.configuration?.attributedTitle = {
            var attributes = AttributeContainer()
            attributes.font = UIFontMetrics.default.scaledFont(
                for: .systemFont(ofSize: 16, weight: .medium)
            )
            attributes.foregroundColor = R.color.theme()
            return AttributedString(
                R.string.localizable.what_is_pin(),
                attributes: attributes
            )
        }()
        explainPINButton.titleLabel?.adjustsFontForContentSizeCategory = true
        
        selectedAnswer = nil
    }
    
    @IBAction func checkAnswer(_ sender: Any) {
        guard let selectedAnswer else {
            return
        }
        let answer = TIPQuizAnswerViewController(answer: selectedAnswer)
        answer.onTryAgain = { [weak self] in
            guard let self else {
                return
            }
            for indexPath in self.collectionView.indexPathsForSelectedItems ?? [] {
                self.collectionView.deselectItem(at: indexPath, animated: false)
            }
            self.selectedAnswer = nil
        }
        answer.onFinish = { [weak self] in
            self?.continueCreatePIN()
        }
        present(answer, animated: true)
    }
    
    @IBAction func explainPIN(_ sender: Any) {
        let safari = SFSafariViewController(url: .whatIsPIN)
        present(safari, animated: true)
    }
    
    @objc private func presentCustomerService(_ sender: Any) {
        let customerService = CustomerServiceViewController()
        present(customerService, animated: true)
    }
    
    private func continueCreatePIN() {
        let action = TIPActionViewController(action: .create(pin: pin))
        navigationController?.setViewControllers([action], animated: true)
    }
    
}

extension TIPQuizViewController: UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        Section.allCases.count
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .question:
            1
        case .answer:
            TIPQuizAnswer.allCases.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .question:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.tip_quiz_question, for: indexPath)!
            return cell
        case .answer:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.tip_quiz_answer, for: indexPath)!
            let answer = TIPQuizAnswer(rawValue: indexPath.item)!
            cell.isSelected = answer == selectedAnswer
            cell.label.text = switch answer {
            case .wrong:
                R.string.localizable.tip_quiz_wrong_answer()
            case .correct:
                R.string.localizable.tip_quiz_correct_answer()
            }
            return cell
        }
    }
    
}

extension TIPQuizViewController: UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        switch Section(rawValue: indexPath.section)! {
        case .question:
            false
        case .answer:
            true
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, shouldDeselectItemAt indexPath: IndexPath) -> Bool {
        false
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section)! {
        case .question:
            break
        case .answer:
            selectedAnswer = TIPQuizAnswer(rawValue: indexPath.item)!
        }
    }
    
}
