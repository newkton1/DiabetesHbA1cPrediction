//
//  PrivacyPolicyView.swift
//  DiabetesHbA1cPrediction
//
//  Loads the live privacy policy from GitHub Pages so there is a single
//  source of truth. Updating the GitHub page automatically updates the
//  in-app view — no code change required.
//

import SwiftUI
import WebKit

struct PrivacyPolicyView: View {

    private let url = URL(string: "https://newkton1.github.io/diabetes-feast-privacy/")!

    var body: some View {
        PrivacyWebView(url: url)
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - WKWebView wrapper

struct PrivacyWebView: UIViewRepresentable {

    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Always fetch fresh content — never serve a stale cached page.
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        webView.load(request)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, WKNavigationDelegate {
        /// Open any tapped links (e.g. the mailto: contact link) in Safari
        /// rather than trying to navigate within the web view.
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                await UIApplication.shared.open(url)
                return .cancel
            }
            return .allow
        }
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
}
