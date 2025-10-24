#if canImport(WebKit)


import UIKit
import WebKit
import SwiftUI

class WebViewController: UIViewController, WKUIDelegate, WKNavigationDelegate {
    
    private var webView: WKWebView!
    
    override func loadView() {
        
        // Configure the web view
        let webConfiguration = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.uiDelegate = self
        webView.navigationDelegate = self
        view = webView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // The notice should automatically get hidden in the web view as consent is passed from the mobile app to the website. However, it might happen that the notice gets displayed for a very short time before being hidden. You can disable the notice in your web view to make sure that it never shows by appending didomiConfig.notice.enable=false to the query string of the URL that you are loading
        let myURL = URL(string:"https://launchdarkly.com/")!
        let myRequest = URLRequest(url: myURL)
        webView.load(myRequest)
    }
}

struct WebViewControllertView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        WebViewController()
    }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

#endif
