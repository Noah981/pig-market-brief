#if WIDGET_PREVIEW
import SwiftUI
import WidgetKit

@main struct WidgetPreviewApp: App {
    var body: some Scene { WindowGroup { Text("Widget verification").onAppear { render() } } }
    @MainActor private func render() {
        let sample = PriceSnapshot(price: 6051, change: 30, percent: 0.5, basisDate: "20261002", checkedAt: Date(), stale: false)
        let snapshots: [(String, AnyView, CGSize)] = [
            ("home_169", AnyView(HomePriceView(snapshot: sample)), CGSize(width: 169, height: 169)),
            ("home_180", AnyView(HomePriceView(snapshot: sample)), CGSize(width: 180, height: 180)),
            ("lock_rectangular", AnyView(LockPriceView(snapshot: sample, family: .accessoryRectangular)), CGSize(width: 160, height: 70)),
            ("lock_circular", AnyView(LockPriceView(snapshot: sample, family: .accessoryCircular)), CGSize(width: 76, height: 76)),
            ("home_empty", AnyView(HomePriceView(snapshot: .empty)), CGSize(width: 169, height: 169))
        ]
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        for (name, view, size) in snapshots {
            let content = view.frame(width: size.width, height: size.height)
                .background(LinearGradient(colors: [Color.white, Color(red: 1, green: 0.965, blue: 0.98)], startPoint: .leading, endPoint: .trailing))
                .clipShape(RoundedRectangle(cornerRadius: name.hasPrefix("home") ? 22 : 0))
                .environment(\.locale, Locale(identifier: "ko_KR"))
            let renderer = ImageRenderer(content: content); renderer.scale = 3
            if let data = renderer.uiImage?.pngData() { try? data.write(to: directory.appendingPathComponent(name + ".png")) }
        }
        // Verify parsing and prevent a different price scope from being displayed.
        let valid = Data("{\"price\":6051,\"change\":30,\"changePct\":0.5,\"date\":\"20261002\",\"scope\":\"전국·탕박·등외제외·제주제외\"}".utf8)
        precondition(PriceSnapshot.decode(valid)?.value == "6,051")
        precondition(PriceSnapshot.decode(Data("{\"price\":0,\"date\":\"20261002\"}".utf8)) == nil)
        precondition(PriceSnapshot.decode(Data("{\"price\":6051,\"date\":\"20261002\",\"scope\":\"제주 포함\"}".utf8)) == nil)
        try? Data("snapshot and data parsing checks passed".utf8).write(to: directory.appendingPathComponent("verified.txt"))
    }
}
#endif
