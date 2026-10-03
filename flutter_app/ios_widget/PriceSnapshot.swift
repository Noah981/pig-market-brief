import Foundation

struct PriceSnapshot: Codable {
    let price: Double?
    let change: Double?
    let percent: Double?
    let basisDate: String
    let checkedAt: Date
    let stale: Bool
    static let empty = PriceSnapshot(price: nil, change: nil, percent: nil, basisDate: "", checkedAt: .distantPast, stale: true)
    static func decode(_ data: Data, stale: Bool = false) -> PriceSnapshot? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let row = root["price"] as? [String: Any] ?? root
        guard let price = row["price"] as? NSNumber, price.doubleValue > 0,
              let date = row["date"] as? String, date.count == 8,
              date.allSatisfy({ $0.isNumber }) else { return nil }
        if let scope = row["scope"] as? String, !scope.contains("제주제외") && !scope.contains("제주 제외") { return nil }
        return PriceSnapshot(price: price.doubleValue, change: (row["change"] as? NSNumber)?.doubleValue,
            percent: (row["changePct"] as? NSNumber)?.doubleValue, basisDate: date, checkedAt: Date(), stale: stale)
    }
    var value: String { guard let price else { return "—" }; return Self.format(price) }
    var comparison: String {
        guard let change else { return "전일 비교 확인 중" }
        let arrow = change > 0 ? "▲ +" : change < 0 ? "▼ " : "— "
        let pct = percent.map { String(format: " (%@%.1f%%)", $0 > 0 ? "+" : "", $0) } ?? ""
        return arrow + Self.format(change) + pct
    }
    var basis: String {
        guard basisDate.count == 8 else { return "기준일 확인 중" }
        let month = basisDate.dropFirst(4).prefix(2), day = basisDate.suffix(2)
        return "\(month)/\(day) 기준"
    }
    private static func format(_ number: Double) -> String {
        let formatter = NumberFormatter(); formatter.locale = Locale(identifier: "ko_KR")
        formatter.numberStyle = .decimal; formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: number)) ?? "—"
    }
}

enum PriceSharedStore {
    static let group = "group.com.example.dondonhae.market"
    static let key = "pigPriceSnapshot"
    static func read() -> PriceSnapshot? {
        guard let data = UserDefaults(suiteName: group)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(PriceSnapshot.self, from: data)
    }
    static func save(_ snapshot: PriceSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults(suiteName: group)?.set(data, forKey: key)
    }
}
