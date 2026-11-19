//
//  Copyright © 2026 Octopus Community. All rights reserved.
//

import UIKit

/// One page of the fullscreen viewer: its zoomable photo, a spinner while the photo is loading, and an error with a
/// Retry button when it could not be loaded.
final class FullscreenViewerPageView: UIView {
    let zoomingPage = ZoomingImagePageView(frame: .zero)
    let spinner = UIActivityIndicatorView(style: .large)
    /// The error and its Retry button, in place of the spinner once the photo could not be loaded.
    let failureView = UIStackView()
    let failureLabel = UILabel()
    let retryButton = UIButton(type: .system)

    private var retry: (() -> Void)?

    private enum Dimensions {
        static let failureSpacing: CGFloat = 16
        static let failureMargin: CGFloat = 24
        static let minimumTapSide: CGFloat = 44
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(zoomingPage)
        spinner.color = .white
        spinner.hidesWhenStopped = true
        addSubview(spinner)
        setUpFailureView()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setUpFailureView() {
        failureLabel.textColor = .white
        failureLabel.textAlignment = .center
        failureLabel.numberOfLines = 0
        failureLabel.font = .preferredFont(forTextStyle: .body)
        failureLabel.adjustsFontForContentSizeCategory = true

        retryButton.tintColor = .white
        retryButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        retryButton.titleLabel?.adjustsFontForContentSizeCategory = true
        retryButton.addTarget(self, action: #selector(retryLoading), for: .touchUpInside)

        failureView.axis = .vertical
        failureView.alignment = .center
        failureView.spacing = Dimensions.failureSpacing
        failureView.isHidden = true
        failureView.addArrangedSubview(failureLabel)
        failureView.addArrangedSubview(retryButton)
        failureView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(failureView)
        NSLayoutConstraint.activate([
            failureView.centerXAnchor.constraint(equalTo: centerXAnchor),
            failureView.centerYAnchor.constraint(equalTo: centerYAnchor),
            failureView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: Dimensions.failureMargin),
            failureView.trailingAnchor.constraint(
                lessThanOrEqualTo: trailingAnchor, constant: -Dimensions.failureMargin),
            retryButton.heightAnchor.constraint(greaterThanOrEqualToConstant: Dimensions.minimumTapSide),
            retryButton.widthAnchor.constraint(greaterThanOrEqualToConstant: Dimensions.minimumTapSide)
        ])
    }

    /// Shows the photo, or the spinner without one. Without a photo, the page cannot be zoomed.
    func setImage(_ image: UIImage?) {
        zoomingPage.image = image
        failureView.isHidden = true
        retry = nil
        if image == nil {
            spinner.startAnimating()
        } else {
            spinner.stopAnimating()
        }
    }

    /// Shows the error in place of the spinner. The Retry button shows the spinner again and calls `retry`.
    func showFailure(message: String, retryTitle: String, retry: @escaping () -> Void) {
        zoomingPage.image = nil
        spinner.stopAnimating()
        failureLabel.text = message
        retryButton.setTitle(retryTitle, for: .normal)
        self.retry = retry
        failureView.isHidden = false
    }

    /// What the Retry button does: shows the spinner again and loads the photo again.
    @objc func retryLoading() {
        let retry = retry
        setImage(nil)
        retry?()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        zoomingPage.frame = bounds
        spinner.center = CGPoint(x: bounds.midX, y: bounds.midY)
    }
}
