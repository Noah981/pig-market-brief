import UIKit
import Flutter
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var widgetChannel: FlutterMethodChannel?
    private var widgetRoute: String?
    override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        widgetRoute = (launchOptions?[.url] as? URL)?.absoluteString
        GeneratedPluginRegistrant.register(with: self)
        let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
        if let controller = window?.rootViewController as? FlutterViewController {
            let channel = FlutterMethodChannel(name: "dondonhae/widgets", binaryMessenger: controller.binaryMessenger)
            widgetChannel = channel
            channel.setMethodCallHandler { [weak self] call, result in
                if call.method == "updateWidgets" {
                    if let raw = UserDefaults.standard.string(forKey: "flutter.official_dabom_producer_pig_price_v4"),
                       let data = raw.data(using: .utf8), let snapshot = PriceSnapshot.decode(data) {
                        let cached = PriceSharedStore.read()
                        if snapshot.basisDate >= (cached?.basisDate ?? "") { PriceSharedStore.save(snapshot) }
                    }
                    WidgetCenter.shared.reloadTimelines(ofKind: "DondonhaePigPrice"); result(true)
                } else if call.method == "getInitialRoute" {
                    result(self?.widgetRoute); self?.widgetRoute = nil
                } else { result(FlutterMethodNotImplemented) }
            }
        }
        return launched
    }
    override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        if url.scheme == "dondonhae" { widgetRoute = url.absoluteString; widgetChannel?.invokeMethod("openRoute", arguments: url.absoluteString); return true }
        return super.application(app, open: url, options: options)
    }
}
