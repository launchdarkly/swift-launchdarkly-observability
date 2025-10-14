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
