import SwiftUI
import StoreKit

/// The subscription and credit surface.
///
/// Written to be honest about what the free tier already does, because it does
/// a lot: on-device Apple Intelligence, every HealthKit chart, correlations,
/// and bring-your-own-key. Someone who never pays still has a working app.
/// What money buys is not having to think about any of that — hosted models
/// without a key of your own, plus sync and the wearables.
///
/// Overstating the wall would be both dishonest and a review risk: App Review
/// looks unkindly on a paywall that hides what the screenshots promised.
struct PaywallView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Kicker(text: "Personal OS", color: Theme.amber, size: 11)
                    .padding(.top, 12)
                    .flowIn(0)

                Text(store.entitlement.isSubscribed ? "You're subscribed." : "Go further.")
                    .font(Theme.serif(34))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 8)
                    .flowIn(1)

                Text(blurb)
                    .font(Theme.serifBody(17))
                    .foregroundStyle(Theme.mid)
                    .lineSpacing(5)
                    .padding(.top, 10)
                    .flowIn(2)

                if store.entitlement.credits > 0 {
                    Plate {
                        VStack(alignment: .leading, spacing: 5) {
                            Kicker(text: "Balance", size: 9)
                            Text("\(store.entitlement.credits)")
                                .font(Theme.serif(30))
                                .foregroundStyle(Theme.ink)
                            Text("hosted readings left")
                                .font(Theme.sans(10.5))
                                .foregroundStyle(Theme.dust)
                        }
                    }
                    .padding(.top, 20)
                }

                SectionRule(text: "Always free").padding(.top, 30)
                VStack(alignment: .leading, spacing: 8) {
                    freeLine("Readings written on this iPhone, privately")
                    freeLine("Every chart, metric and correlation")
                    freeLine("Your own API key, if you have one")
                }
                .padding(.top, 14)

                if !store.entitlement.isSubscribed {
                    SectionRule(text: "Subscription").padding(.top, 30)
                    VStack(spacing: 0) {
                        Rule()
                        ForEach(store.subscriptions(), id: \.id) { p in
                            purchaseRow(p, note: p.subscription.map(periodLabel) ?? "")
                            Rule()
                        }
                    }
                    .padding(.top, 14)
                }

                SectionRule(text: "Or buy readings").padding(.top, 30)
                Text("No subscription. Credits don't expire, and a subscription never spends them.")
                    .font(Theme.sans(11))
                    .foregroundStyle(Theme.dust)
                    .lineSpacing(3)
                    .padding(.top, 10)

                VStack(spacing: 0) {
                    Rule()
                    ForEach(store.creditPacks(), id: \.id) { p in
                        purchaseRow(p, note: "one-off")
                        Rule()
                    }
                }
                .padding(.top, 14)

                if let err = store.lastError {
                    Text(err)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.mid)
                        .lineSpacing(4)
                        .padding(.top, 18)
                }

                Button {
                    Task { await store.restore() }
                } label: {
                    Kicker(text: "Restore purchases", size: 10)
                }
                .buttonStyle(.press)
                .padding(.top, 28)

                Text("Payment is charged to your Apple Account. Subscriptions renew unless cancelled at least 24 hours before the period ends; manage them in Settings.")
                    .font(Theme.sans(9.5))
                    .foregroundStyle(Theme.dust)
                    .lineSpacing(3)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
            }
            // What you own changes what this screen offers; a purchase or a
            // restore should redraw it in one movement rather than three.
            .animation(Theme.Motion.flow, value: store.lastError)
            .animation(Theme.Motion.flow, value: store.entitlement.isSubscribed)
            .animation(Theme.Motion.flow, value: store.entitlement.credits)
            .padding(.horizontal, 24)
        }
        .background(Theme.linen)
        .navigationTitle("Plans")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.loadProducts()
            await store.refresh()
        }
    }

    private var blurb: String {
        if store.entitlement.isSubscribed {
            return "Hosted readings, cloud sync and the wearable connections are all yours."
        }
        return "The app works without paying. A subscription adds hosted readings without needing your own API key, cloud sync, and the wearable connections."
    }

    private func freeLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Text("❧").font(Theme.serif(12)).foregroundStyle(Theme.sage)
            Text(text)
                .font(Theme.serifBody(16))
                .foregroundStyle(Theme.ink)
        }
    }

    private func periodLabel(_ s: Product.SubscriptionInfo) -> String {
        switch s.subscriptionPeriod.unit {
        case .month: return "per month"
        case .year: return "per year"
        case .week: return "per week"
        case .day: return "per day"
        @unknown default: return ""
        }
    }

    private func purchaseRow(_ product: Product, note: String) -> some View {
        Button {
            Task { await store.purchase(product) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(product.displayName)
                        .font(Theme.serif(19))
                        .foregroundStyle(Theme.ink)
                    if !note.isEmpty {
                        Text(note)
                            .font(Theme.sans(10.5))
                            .foregroundStyle(Theme.dust)
                    }
                }
                Spacer()
                Text(product.displayPrice)
                    .font(Theme.serif(19))
                    .foregroundStyle(Theme.amber)
            }
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressRow)
        .disabled(store.isWorking)
    }
}
