import Cocoa

extension NSWindow {
  func fadeIn(duration: TimeInterval = 0.125, callback: (() -> Void)? = nil) {
    alphaValue = 0

    NSAnimationContext.runAnimationGroup { context in
      context.duration = duration
      animator().alphaValue = 1
    } completionHandler: {
      callback?()
    }
  }

  func fadeOut(duration: TimeInterval = 0.125, callback: (() -> Void)? = nil) {
    alphaValue = 1

    NSAnimationContext.runAnimationGroup { context in
      context.duration = duration
      animator().alphaValue = 0
    } completionHandler: {
      callback?()
    }
  }

  func shake() {
    let numberOfShakes = 3
    let durationOfShake = 0.4
    let vigourOfShake = 0.03
    let frame: CGRect = self.frame
    let shakeAnimation = CAKeyframeAnimation()

    let shakePath = CGMutablePath()
    shakePath.move(to: CGPoint(x: NSMinX(frame), y: NSMinY(frame)))

    for _ in 0...numberOfShakes - 1 {
      shakePath.addLine(
        to: CGPoint(x: NSMinX(frame) - frame.size.width * vigourOfShake, y: NSMinY(frame)))
      shakePath.addLine(
        to: CGPoint(x: NSMinX(frame) + frame.size.width * vigourOfShake, y: NSMinY(frame)))
    }

    shakePath.closeSubpath()
    shakeAnimation.path = shakePath
    shakeAnimation.duration = durationOfShake

    let animations = [NSAnimatablePropertyKey("frameOrigin"): shakeAnimation]

    self.animations = animations
    animator().setFrameOrigin(NSPoint(x: frame.minX, y: frame.minY))
  }
}
