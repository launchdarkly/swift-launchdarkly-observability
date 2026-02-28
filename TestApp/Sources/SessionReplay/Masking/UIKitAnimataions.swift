import UIKit

func startRotating(view: UIView, duration: TimeInterval = 10.0) {
    let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
    rotation.fromValue = Double.pi * 2
    rotation.toValue = Double.pi * 0
    rotation.duration = duration
    rotation.repeatCount = .infinity
    rotation.isRemovedOnCompletion = false
    view.layer.anchorPoint = CGPoint(x: 0.5, y: 0.25)
    view.layer.add(rotation, forKey: "rotationAnimation")
}

func startSlidingFromRight(view v: UIView, duration: TimeInterval = 26.0) {
    //guard let superview = v.superview else { return }
    
    let startX: CGFloat = v.bounds.width
    let endX: CGFloat = -v.bounds.width

    v.frame.origin.x = startX
    UIView.animate(withDuration: duration,
                   delay: 0, options: [.repeat, .curveLinear],
                   animations: {
        v.frame.origin.x = endX
    })
}

func startSlidingFromBottom(view v: UIView, duration: TimeInterval = 15.0) {
    //guard let superview = v.superview else { return }
    
    let startY: CGFloat = v.bounds.height
    let endY: CGFloat = -v.bounds.height

    v.frame.origin.y = startY
    UIView.animate(withDuration: duration,
                   delay: 0, options: [.repeat, .curveLinear],
                   animations: {
        v.frame.origin.y = endY
    })
}

func blink(view v: UIView, rate: Double = 0.2) {
    // rate is in blinks per second (Hz). One full blink cycle duration = 1 / rate seconds.
    // We want a 10% pause while fully transparent (alpha = 0).
    guard rate > 0 else { return }

    // Total duration for a full blink cycle (visible -> transparent (pause) -> visible)
    let cycle = 1.0 / rate
    let pausePortion = 0.30 // 10% of the cycle paused at alpha = 0

    // Split remaining time equally between fade out and fade in
    let transitionPortion = (1.0 - pausePortion) / 2.0

    // Ensure starting from fully visible state
    v.alpha = 1.0

    UIView.animateKeyframes(withDuration: cycle,
                            delay: 0,
                            options: [.repeat, .calculationModeLinear, .allowUserInteraction],
                            animations: {
        // Fade out: 0.0 -> transitionPortion
        UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: transitionPortion) {
            v.alpha = 0.0
        }
        // Pause at transparent: transitionPortion -> transitionPortion + pausePortion
        UIView.addKeyframe(withRelativeStartTime: transitionPortion, relativeDuration: pausePortion) {
            v.alpha = 0.0
        }
        // Fade in: transitionPortion + pausePortion -> 1.0
        UIView.addKeyframe(withRelativeStartTime: transitionPortion + pausePortion, relativeDuration: transitionPortion) {
            v.alpha = 1.0
        }
    }, completion: nil)
}
