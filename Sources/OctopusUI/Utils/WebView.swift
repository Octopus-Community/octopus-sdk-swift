//
//  Copyright © 2024 Octopus Community. All rights reserved.
//

import Foundation
import SwiftUI
import WebKit

private struct WKWebViewForSwiftUI: UIViewRepresentable {

    let url: URL
    @Binding var isLoading: Bool

    func makeUIView(context: Context) -> some UIView {
        let webview = WKWebView()
        webview.navigationDelegate = context.coordinator
        webview.load(URLRequest(url: url))
        return webview
    }

    func updateUIView(_ uiView: UIViewType, context: Context) {

    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        private let parent: WKWebViewForSwiftUI
        init(_ parent: WKWebViewForSwiftUI) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
        }
    }
}

struct WebView: View {
    let url: URL

    @State var isLoading: Bool = false

    var body: some View {
        LoadingView(isLoading: isLoading) {
            WKWebViewForSwiftUI(url: url, isLoading: $isLoading)
        }
    }
}
