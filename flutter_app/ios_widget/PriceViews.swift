import SwiftUI
import WidgetKit

struct HomePriceView: View {
    let snapshot: PriceSnapshot
    var body: some View {
        GeometryReader { geometry in
            let scale = min(geometry.size.width / 169, 1.35)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5 * scale) {
                    Image("PigLogo").resizable().scaledToFit().frame(width: 19 * scale, height: 19 * scale)
                    Text("돈돈해").font(.system(size: 13 * scale, weight: .bold))
                    Spacer(minLength: 2)
                    Text(Date(), format: .dateTime.month(.twoDigits).day().weekday(.abbreviated))
                        .font(.system(size: 7 * scale)).foregroundStyle(Color.gray).lineLimit(1).minimumScaleFactor(0.7)
                }
                .padding(.bottom, 9 * scale)
                Text("전국 평균 돈가").font(.system(size: 10 * scale, weight: .bold))
                Text(snapshot.basis).font(.system(size: 9 * scale)).foregroundStyle(Color.gray).padding(.top, 3 * scale)
                HStack(alignment: .firstTextBaseline, spacing: 3 * scale) {
                    Text(snapshot.value).font(.system(size: 29 * scale, weight: .medium, design: .rounded))
                        .minimumScaleFactor(0.6).lineLimit(1)
                    Text("원/kg").font(.system(size: 11 * scale, weight: .medium)).fixedSize()
                }.foregroundStyle(Color(red: 0.04, green: 0.09, blue: 0.19)).padding(.top, 4 * scale)
                Text(snapshot.comparison).font(.system(size: 12 * scale, weight: .semibold))
                    .foregroundStyle(snapshot.change.map { $0 < 0 } == true ? Color(red: 0.12, green: 0.53, blue: 0.83) : Color(red: 0.91, green: 0.19, blue: 0.43))
                    .lineLimit(1).minimumScaleFactor(0.65).padding(.top, 5 * scale)
                if snapshot.stale {
                    Text(snapshot.price == nil ? "데이터 확인 중" : "마지막 저장값 · 업데이트 확인 필요")
                        .font(.system(size: 7 * scale)).foregroundStyle(.secondary).lineLimit(1).padding(.top, 4 * scale)
                }
                Spacer(minLength: 0)
            }
            .padding(12 * scale)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

struct LockPriceView: View {
    let snapshot: PriceSnapshot
    let family: WidgetFamily
    var body: some View {
        switch family {
        case .accessoryInline:
            Text("돈가 \(snapshot.value)원 \(snapshot.comparison)")
        case .accessoryCircular:
            VStack(spacing: 1) {
                Text("돈가").font(.system(size: 9))
                Text(snapshot.value).font(.system(size: 14, weight: .bold)).minimumScaleFactor(0.55).lineLimit(1)
                Text(snapshot.stale ? "저장값" : snapshot.basis).font(.system(size: 7)).lineLimit(1)
            }.widgetAccentable()
        default:
            VStack(alignment: .leading, spacing: 1) {
                Text("전국 돈가 · \(snapshot.basis)").font(.system(size: 10)).lineLimit(1)
                Text("\(snapshot.value) 원/kg").font(.system(size: 20, weight: .bold)).minimumScaleFactor(0.7).lineLimit(1)
                Text(snapshot.stale ? "\(snapshot.comparison) · 저장값" : snapshot.comparison)
                    .font(.system(size: 10)).minimumScaleFactor(0.65).lineLimit(1)
            }.widgetAccentable()
        }
    }
}
