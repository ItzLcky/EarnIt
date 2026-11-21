import SwiftUI
import StoreKit

struct SupportView: View {
    @EnvironmentObject private var tipJar: TipJar

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.pink)
                Text("EarnIt is free. Forever.")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text("No subscriptions, no premium tier, no ads, no accounts, no tracking. Every feature is free for everyone. If EarnIt helps you take your time back, a tip keeps it running.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Card {
                    if tipJar.products.isEmpty {
                        HStack {
                            Spacer()
                            if tipJar.loadFailed {
                                Text("Tips are unavailable right now.").foregroundStyle(.secondary)
                            } else {
                                ProgressView()
                            }
                            Spacer()
                        }
                    } else {
                        ForEach(tipJar.products) { product in
                            Button {
                                Task { await tipJar.tip(product) }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(product.displayName).font(.headline)
                                        Text(product.description).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if tipJar.purchasing == product.id {
                                        ProgressView()
                                    } else {
                                        Text(product.displayPrice)
                                            .font(.headline)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(Color.accentColor, in: Capsule())
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(tipJar.purchasing != nil)
                        }
                    }
                }

                Text("Tips are one-time and unlock nothing extra. That's the point.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Support")
        .navigationBarTitleDisplayMode(.inline)
        .task { await tipJar.load() }
        .alert("Thank you! 🧡", isPresented: $tipJar.thankYou) {
            Button("You're welcome") {}
        } message: {
            Text("Your tip keeps EarnIt free for everyone.")
        }
    }
}
