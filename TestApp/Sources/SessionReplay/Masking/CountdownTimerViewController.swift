#if os(iOS)
import UIKit

final class CountdownTimerViewController: UIViewController {
    var duration: Int = 60
    var onComplete: (() -> Void)?

    private var remaining: Int = 60
    private var countdownTimer: Timer?

    private let progressLayer = CAShapeLayer()
    private let trackLayer = CAShapeLayer()
    private let timeLabel = UILabel()
    private let subtitleLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        remaining = duration
        view.backgroundColor = .systemBackground
        setupUI()
        startTimer()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopTimer()
    }

    private func setupUI() {
        let center = CGPoint(x: 80, y: 80)
        let radius: CGFloat = 76
        let circularPath = UIBezierPath(
            arcCenter: center, radius: radius,
            startAngle: -.pi / 2, endAngle: .pi * 1.5, clockwise: true
        )

        trackLayer.path = circularPath.cgPath
        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.strokeColor = UIColor.systemGray5.cgColor
        trackLayer.lineWidth = 8

        progressLayer.path = circularPath.cgPath
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeColor = UIColor.systemBlue.cgColor
        progressLayer.lineWidth = 8
        progressLayer.lineCap = .round
        progressLayer.strokeEnd = 1.0

        let circleContainer = UIView()
        circleContainer.translatesAutoresizingMaskIntoConstraints = false
        circleContainer.layer.addSublayer(trackLayer)
        circleContainer.layer.addSublayer(progressLayer)

        timeLabel.font = .monospacedDigitSystemFont(ofSize: 40, weight: .medium)
        timeLabel.textAlignment = .center
        timeLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.text = "Time Remaining"
        subtitleLabel.font = .preferredFont(forTextStyle: .caption1)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        circleContainer.addSubview(timeLabel)
        circleContainer.addSubview(subtitleLabel)

        var config = UIButton.Configuration.filled()
        config.title = "Stop"
        config.buttonSize = .large
        let stopButton = UIButton(configuration: config)
        stopButton.addTarget(self, action: #selector(stopTapped), for: .touchUpInside)
        stopButton.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [circleContainer, stopButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            circleContainer.widthAnchor.constraint(equalToConstant: 160),
            circleContainer.heightAnchor.constraint(equalToConstant: 160),
            timeLabel.centerXAnchor.constraint(equalTo: circleContainer.centerXAnchor),
            timeLabel.centerYAnchor.constraint(equalTo: circleContainer.centerYAnchor, constant: -10),
            subtitleLabel.centerXAnchor.constraint(equalTo: circleContainer.centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: timeLabel.bottomAnchor, constant: 4),
        ])

        updateDisplay()
    }

    private func startTimer() {
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.remaining > 0 {
                self.remaining -= 1
                self.updateDisplay()
            } else {
                self.stopTimer()
                self.onComplete?()
            }
        }
    }

    private func stopTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    private func updateDisplay() {
        let minutes = remaining / 60
        let seconds = remaining % 60
        timeLabel.text = String(format: "%02d:%02d", minutes, seconds)
        progressLayer.strokeEnd = CGFloat(remaining) / CGFloat(duration)
    }

    @objc private func stopTapped() {
        stopTimer()
        onComplete?()
    }

    @objc func dismissSelf() {
        dismiss(animated: true)
    }
}
#endif
