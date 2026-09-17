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
                Kicker(text: "Personal OS", color: Theme.accent, size: 11)
                    .padding(.top, 12)
                    .flowIn(0)

                Text(store.entitlement.isSubscribed ? "You're subscribed." : "Read the archive.")
                    .font(Theme.serif(34))
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)

                Text(blurb)
                    .font(Theme.serifBody(17))
                    .foregroundStyle(Theme.secondaryText)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)

                VStack(alignment: .leading, spacing: 10) {
                    point("Every article, including ones no longer on Home")
                    point("New writing stays free while it is on Home")
                    point("Readings, goals and the cycle are free and always were")
                }
                .padding(.top, 24)

                if nothingToBuy {
                    SectionRule(text: "Not yet").padding(.top, 30)
                    Text("""
                    The App Store has no subscription to offer for this build \
                    yet, so there is nothing to buy here. Everything the app \
                    does on the phone is unaffected and costs nothing.
                    """)
                        .font(Theme.serifBody(16))
                        .foregroundStyle(Theme.secondaryText)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 12)
                } else if !store.entitlement.isSubscribed {
                    SectionRule(text: "Subscription").padding(.top, 30)
                    VStack(spacing: 0) {
                        ForEach(store.subscriptions(), id: \.id) { p in
                            purchaseRow(p, note: p.subscription.map(periodLabel) ?? "")
                        }
                    }
                    .padding(.top, 14)
                }

                if let err = store.lastError {
                    Text(err)
                        .font(Theme.sans(12))
                        .foregroundStyle(Theme.secondaryText)
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
                    .foregroundStyle(Theme.tertiaryText)
                    .lineSpacing(3)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
            }
            // What you own changes what this screen offers; a purchase or a
            // restore should redraw it in one movement rather than three.
            .animation(Theme.Motion.flow, value: store.lastError)
            .animation(Theme.Motion.flow, value: store.entitlement.isSubscribed)
            .padding(.horizontal, 24)
        }
        .compactsTabBar()
        .background(Theme.background)
        .navigationTitle("Plans")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.loadProducts()
            await store.refresh()
        }
    }

    private var nothingToBuy: Bool { store.subscriptions().isEmpty }

    private var blurb: String {
        if store.entitlement.isSubscribed {
            return "The whole archive is open to you, and stays open while the subscription runs."
        }
        return "The app works without paying, and the parts that read your body always will. What a subscription buys is the writing: every article, including the ones whose time on Home has passed."
    }

    /// One line of what the subscription includes.
    private func point(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Text("\u{2767}")
                .font(Theme.serif(12))
                .foregroundStyle(Theme.accent)
                .padding(.top, 3)
            Text(text)
                .font(Theme.sans(14.5))
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func freeLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Text("❧").font(Theme.serif(12)).foregroundStyle(Theme.positive)
            Text(text)
                .font(Theme.serifBody(16))
                .foregroundStyle(Theme.text)
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
                        .foregroundStyle(Theme.text)
                    if !note.isEmpty {
                        Text(note)
                            .font(Theme.sans(10.5))
                            .foregroundStyle(Theme.tertiaryText)
                    }
                }
                Spacer()
                Text(product.displayPrice)
                    .font(Theme.serif(19))
                    .foregroundStyle(Theme.accent)
            }
            .padding(.vertical, 15)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressRow)
        .disabled(store.isWorking)
    }
}
