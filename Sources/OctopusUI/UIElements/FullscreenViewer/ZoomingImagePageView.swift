//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import UIKit

/// One photo of the fullscreen viewer, zoomable between the scale at which it is shown whole and 5 times that scale.
///
/// The photo is laid out at its own size and the scroll view zooms it: the fit scale is the minimum zoom, so the
/// photo can never be made smaller than the screen allows. While it is smaller than the page, content insets keep it
/// centred.
final class ZoomingImagePageView: UIScrollView, UIScrollViewDelegate {
    /// How much a VoiceOver zoom action zooms in or out.
    private static let accessibilityZoomStep: CGFloat = 1.5
    /// How far a VoiceOver move action moves a zoomed photo, as a fraction of the visible width or height.
    private static let accessibilityMoveFraction: CGFloat = 0.25

    /// The photo, laid out at its own size and zoomed by the scroll view.
    let imageView = UIImageView()

    /// The photo shown. Setting it brings the zoom back to fit, centred. Without a photo, zoom is disabled.
    var image: UIImage? {
        didSet {
            guard image !== oldValue else { return }
            imageDidChange()
        }
    }

    /// Called with whether the photo is zoomed in, each time that changes.
    var onZoomChange: ((Bool) -> Void)?

    /// The locale the VoiceOver actions are named in, when the SDK overrides the language of the device.
    var locale: Locale? {
        didSet { updateAccessibilityActions() }
    }

    /// Called for the VoiceOver swipe up and down on the photo, set when they change the photo shown: `true` for the
    /// next one, `false` for the previous one. Returns whether the photo changed.
    var onAccessibilityAdjust: ((_ forward: Bool) -> Bool)? {
        didSet {
            if onAccessibilityAdjust == nil {
                accessibilityTraits.remove(.adjustable)
            } else {
                accessibilityTraits.insert(.adjustable)
            }
        }
    }

    /// Plays the feedback of a photo brought back to fit by the reader. Replaced in tests.
    var playHaptic: @MainActor () -> Void = { HapticFeedback.play() }

    /// The recognizer of the double tap that zooms. A single tap recognizer of the viewer has to wait for it to fail.
    private(set) lazy var doubleTapRecognizer: UITapGestureRecognizer = {
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        recognizer.numberOfTapsRequired = 2
        return recognizer
    }()

    /// The scale at which the whole photo is shown in the current bounds.
    private(set) var fitScale: CGFloat = 1

    /// Whether the photo was last reported as zoomed.
    private(set) var isZoomed = false
    /// Whether a return to fit comes from the reader (a pinch or a double tap) and plays the haptic.
    private var isReturnToFitFromReader = false
    /// The bounds size the zoom scales were computed for.
    private var laidOutSize: CGSize = .zero
    /// Whether the photo changed and its zoom has to be brought back to fit at the next layout.
    private var needsZoomReset = true

    override init(frame: CGRect) {
        super.init(frame: frame)
        delegate = self
        showsHorizontalScrollIndicator = false
        showsVerticalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        decelerationRate = .fast
        bouncesZoom = true
        addSubview(imageView)
        addGestureRecognizer(doubleTapRecognizer)
        isAccessibilityElement = true
        accessibilityTraits = .image
        imageDidChange()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != laidOutSize || needsZoomReset else { return }
        updateZoomScales(resetToFit: needsZoomReset)
    }

    /// Zooms to where a double tap leads from the current zoom, centred on `point`, a point in the page's own
    /// coordinates (`location(in:)` of the page).
    func toggleDoubleTapZoom(at point: CGPoint) {
        guard let image, hasUsableBounds else { return }
        let fill = ZoomRules.fillScale(imageSize: image.size, bounds: bounds.size)
        let target = ZoomRules.doubleTapTargetScale(current: zoomScale, fit: fitScale, fill: fill)
        isReturnToFitFromReader = true
        guard ZoomRules.isZoomed(current: target, fit: fitScale) else {
            setZoomScale(fitScale, animated: true)
            return
        }
        let center = convert(point, to: imageView)
        let size = CGSize(width: bounds.width / target, height: bounds.height / target)
        zoom(to: CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2,
                        width: size.width, height: size.height),
             animated: true)
    }

    /// Brings the photo back to fit, without the haptic of a return made by the reader.
    func resetZoom(animated: Bool) {
        isReturnToFitFromReader = false
        setZoomScale(fitScale, animated: animated)
        if !animated {
            centerContent()
            contentOffset = clampedOffset(contentOffset)
        }
    }

    // MARK: UIScrollViewDelegate

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        // Always the image view, even without a photo: its zoom has to come back to 1 when the photo goes away.
        imageView
    }

    func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        // UIKit also calls this for an animated zoom made in code (a reset, or the double tap that marks itself):
        // only a pinch is a return made by the reader.
        switch pinchGestureRecognizer?.state {
        case .began, .changed: isReturnToFitFromReader = true
        default: break
        }
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        centerContent()
        updateZoomState()
    }

    // MARK: Zoom

    private var hasUsableBounds: Bool { bounds.width > 0 && bounds.height > 0 }

    private func imageDidChange() {
        imageView.image = image
        // Zoom scales apply to the photo at its own size: lay it out unzoomed before changing its frame. The fit scale
        // goes to 1 first, so that this step does not count as a zoom.
        isReturnToFitFromReader = false
        fitScale = 1
        minimumZoomScale = 1
        maximumZoomScale = 1
        zoomScale = 1
        imageView.frame = CGRect(origin: .zero, size: image?.size ?? .zero)
        contentSize = imageView.frame.size
        pinchGestureRecognizer?.isEnabled = image != nil
        doubleTapRecognizer.isEnabled = image != nil
        needsZoomReset = true
        updateZoomScales(resetToFit: true)
        updateAccessibilityActions()
    }

    /// Computes the zoom scales for the current bounds. Unless `resetToFit`, a zoomed photo keeps its zoom relative to
    /// the fit scale, centred on the same point, so that a rotation does not lose the reader's place.
    private func updateZoomScales(resetToFit: Bool) {
        guard let image, hasUsableBounds else {
            updateZoomState()
            return
        }
        // The bounds already have their new size: the point the reader was looking at is the centre of the size
        // they were laid out for, from the same origin.
        let previousCenter = laidOutSize == .zero
            ? CGPoint(x: bounds.midX, y: bounds.midY)
            : CGPoint(x: bounds.minX + laidOutSize.width / 2, y: bounds.minY + laidOutSize.height / 2)
        let centerInImage = convert(previousCenter, to: imageView)
        laidOutSize = bounds.size
        needsZoomReset = false
        let previousFit = fitScale
        let keepsZoom = !resetToFit && ZoomRules.isZoomed(current: zoomScale, fit: previousFit)
        let relativeZoom = keepsZoom ? zoomScale / previousFit : 1

        let fit = ZoomRules.fitScale(imageSize: image.size, bounds: bounds.size)
        let isReturnToFitFromReader = isReturnToFitFromReader
        self.isReturnToFitFromReader = false
        fitScale = fit
        minimumZoomScale = fit
        maximumZoomScale = ZoomRules.maxScale(fit: fit)
        zoomScale = fit * relativeZoom
        self.isReturnToFitFromReader = isReturnToFitFromReader

        centerContent()
        if keepsZoom {
            let center = imageView.convert(centerInImage, to: self)
            contentOffset = clampedOffset(CGPoint(x: center.x - bounds.width / 2, y: center.y - bounds.height / 2))
        } else {
            contentOffset = clampedOffset(.zero)
        }
        updateZoomState()
    }

    /// Centres the photo while it is smaller than the page.
    private func centerContent() {
        let horizontal = max((bounds.width - contentSize.width) / 2, 0)
        let vertical = max((bounds.height - contentSize.height) / 2, 0)
        contentInset = UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
    }

    /// `offset` brought inside the scrollable range of the content.
    private func clampedOffset(_ offset: CGPoint) -> CGPoint {
        let minX = -contentInset.left
        let minY = -contentInset.top
        let maxX = max(minX, contentSize.width + contentInset.right - bounds.width)
        let maxY = max(minY, contentSize.height + contentInset.bottom - bounds.height)
        return CGPoint(x: min(max(offset.x, minX), maxX), y: min(max(offset.y, minY), maxY))
    }

    /// Reports a change of the zoomed state, and plays the haptic when the reader brought the photo back to fit.
    private func updateZoomState() {
        let zoomed = image != nil && ZoomRules.isZoomed(current: zoomScale, fit: fitScale)
        guard zoomed != isZoomed else { return }
        isZoomed = zoomed
        // The move actions are only offered on a zoomed photo.
        updateAccessibilityActions()
        if !zoomed && isReturnToFitFromReader {
            isReturnToFitFromReader = false
            playHaptic()
        }
        onZoomChange?(zoomed)
    }

    @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        toggleDoubleTapZoom(at: recognizer.location(in: self))
    }

    // MARK: VoiceOver

    override func accessibilityIncrement() {
        _ = onAccessibilityAdjust?(true)
    }

    override func accessibilityDecrement() {
        _ = onAccessibilityAdjust?(false)
    }

    private func updateAccessibilityActions() {
        guard image != nil else {
            accessibilityCustomActions = nil
            return
        }
        var actions = [
            UIAccessibilityCustomAction(name: L10n("Accessibility.Image.ZoomIn", locale: locale)) { [weak self] _ in
                self?.stepZoom(by: Self.accessibilityZoomStep) ?? false
            },
            UIAccessibilityCustomAction(name: L10n("Accessibility.Image.ZoomOut", locale: locale)) { [weak self] _ in
                self?.stepZoom(by: 1 / Self.accessibilityZoomStep) ?? false
            }
        ]
        if isZoomed {
            // Towards the part of the photo the reader wants to see, as the drag of a finger would bring it.
            let moves: [(key: String, dx: CGFloat, dy: CGFloat)] = [
                ("Accessibility.Image.MoveLeft", -1, 0),
                ("Accessibility.Image.MoveRight", 1, 0),
                ("Accessibility.Image.MoveUp", 0, -1),
                ("Accessibility.Image.MoveDown", 0, 1)
            ]
            actions += moves.map { move in
                UIAccessibilityCustomAction(name: L10n(move.key, locale: locale)) { [weak self] _ in
                    self?.stepMove(dx: move.dx, dy: move.dy) ?? false
                }
            }
        }
        accessibilityCustomActions = actions
    }

    /// Moves a zoomed photo by a quarter of the visible width (`dx`) or height (`dy`), towards the side asked for,
    /// within the photo. Returns false when the photo cannot move that way.
    private func stepMove(dx: CGFloat, dy: CGFloat) -> Bool {
        guard isZoomed else { return false }
        let target = clampedOffset(CGPoint(
            x: contentOffset.x + dx * bounds.width * Self.accessibilityMoveFraction,
            y: contentOffset.y + dy * bounds.height * Self.accessibilityMoveFraction))
        guard abs(target.x - contentOffset.x) > 0.5 || abs(target.y - contentOffset.y) > 0.5 else { return false }
        setContentOffset(target, animated: false)
        return true
    }

    /// Multiplies the zoom by `factor`, within the zoom range. Returns false when the zoom cannot move that way.
    private func stepZoom(by factor: CGFloat) -> Bool {
        let target = min(max(zoomScale * factor, minimumZoomScale), maximumZoomScale)
        guard abs(target - zoomScale) > 0.0001 else { return false }
        isReturnToFitFromReader = false
        setZoomScale(target, animated: false)
        return true
    }
}
