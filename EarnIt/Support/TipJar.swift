import StoreKit

/// Optional tips. Apple requires In-App Purchase for tips to an individual developer,
/// so these are plain consumables that unlock nothing. Every feature stays free.
@MainActor
final class TipJar: ObservableObject {
    static let productIDs = [
        "app.earnit.tip.small",
        "app.earnit.tip.medium",
        "app.earnit.tip.large",
        "app.earnit.tip.huge",
    ]

    @Published var products: [Product] = []
    @Published var purchasing: Product.ID?
    @Published var thankYou = false
    @Published var loadFailed = false

    func load() async {
        guard products.isEmpty else { return }
        do {
            products = try await Product.products(for: Self.productIDs).sorted { $0.price < $1.price }
            loadFailed = products.isEmpty
        } catch {
            loadFailed = true
        }
    }

    func tip(_ product: Product) async {
        purchasing = product.id
        defer { purchasing = nil }
        do {
            let result = try await product.purchase()
            if case .success(let verification) = result, case .verified(let transaction) = verification {
                await transaction.finish()
                thankYou = true
            }
        } catch {
            NSLog("EarnIt: tip failed: \(error)")
        }
    }

    /// Finish any transactions that complete outside the purchase call (e.g. Ask to Buy).
    func listenForTransactions() async {
        for await update in Transaction.updates {
            if case .verified(let transaction) = update {
                await transaction.finish()
            }
        }
    }
}
