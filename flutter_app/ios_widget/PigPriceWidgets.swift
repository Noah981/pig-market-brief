import WidgetKit
import SwiftUI

struct PriceEntry: TimelineEntry { let date: Date; let snapshot: PriceSnapshot }
struct PriceProvider: TimelineProvider {
    func placeholder(in context: Context) -> PriceEntry { PriceEntry(date: Date(), snapshot: .empty) }
    func getSnapshot(in context: Context, completion: @escaping (PriceEntry) -> Void) {
        completion(PriceEntry(date: Date(), snapshot: PriceSharedStore.read() ?? .empty))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PriceEntry>) -> Void) {
        Task {
            let cached = PriceSharedStore.read()
            var snapshot = cached.map { PriceSnapshot(price: $0.price, change: $0.change, percent: $0.percent,
                basisDate: $0.basisDate, checkedAt: $0.checkedAt, stale: true) } ?? .empty
            do {
                var request = URLRequest(url: URL(string: "https://noah981.github.io/pig-market-brief/data/pig-price.json")!)
                request.timeoutInterval = 12; request.cachePolicy = .reloadIgnoringLocalCacheData
                let (data, response) = try await URLSession.shared.data(for: request)
                if (response as? HTTPURLResponse)?.statusCode == 200, let latest = PriceSnapshot.decode(data),
                   latest.basisDate >= (cached?.basisDate ?? "") {
                    snapshot = latest; PriceSharedStore.save(latest)
                }
            } catch { /* Preserve the last verified value with a cache label. */ }
            let now = Date()
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
            let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
            // Preload midnight so the calendar date can advance even if networking is delayed.
            completion(Timeline(entries: [PriceEntry(date: now, snapshot: snapshot), PriceEntry(date: midnight, snapshot: snapshot)],
                policy: .after(min(now.addingTimeInterval(1800), midnight))))
        }
    }
}

struct PriceWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PriceEntry
    var body: some View {
        Group {
            if family == .systemSmall || family == .systemMedium { HomePriceView(snapshot: entry.snapshot, displayDate: entry.date) }
            else { LockPriceView(snapshot: entry.snapshot, family: family) }
        }
        .containerBackground(for: .widget) {
            LinearGradient(colors: [Color.white, Color(red: 1, green: 0.965, blue: 0.98)], startPoint: .leading, endPoint: .trailing)
        }
        .widgetURL(URL(string: "dondonhae://market/pig-price"))
        .environment(\.locale, Locale(identifier: "ko_KR"))
    }
}

@main struct PigPriceWidget: Widget {
    let kind = "DondonhaePigPrice"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PriceProvider()) { PriceWidgetView(entry: $0) }
            .configurationDisplayName("돈돈해 돈가")
            .description("전국 돈가, 전일 대비와 데이터 기준일을 확인합니다.")
            .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline])
            .contentMarginsDisabled()
    }
}
