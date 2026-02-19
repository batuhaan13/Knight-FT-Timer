import SwiftUI
import StoreKit
import Combine

@MainActor
final class SubscriptionViewModel: ObservableObject {
    
    // MARK: - UI State
    @Published var isSubscribed: Bool = false
    @Published var products: [StoreKit.Product] = []
    @Published var isLoading: Bool = false
    @Published var purchaseError: String? = nil
    
    // MARK: - Product IDs
    static let monthlyProductID = "promonth.forgottentempleko"
    static let productIDs: Set<String> = [monthlyProductID]
    
    // MARK: - Init
    init() {
        observeTransactions()
        
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }
    
    // MARK: - Public Helpers
    var currentProduct: StoreKit.Product? {
        products.first { Self.productIDs.contains($0.id) }
    }
    
    /// UI tarafında "Satın Al" butonu bununla çağrılsın (ürün yoksa güvenli şekilde hata gösterir).
    func purchaseCurrent() async {
        guard !isLoading else { return }
        
        guard let product = currentProduct else {
            purchaseError = "Abonelik ürünü yüklenemedi. Lütfen tekrar deneyin."
            return
        }
        await purchase(product: product)
    }
    
    func reloadProducts() async {
        await loadProducts()
    }
    
    // MARK: - Load Products
    func loadProducts() async {
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }
        
        do {
            let fetched = try await StoreKit.Product.products(for: Array(Self.productIDs))
            products = fetched
            
            print("✅ Loaded products count:", fetched.count,
                  "IDs:", fetched.map(\.id))
            
            if fetched.isEmpty {
                purchaseError = "Ürün bulunamadı. Lütfen daha sonra tekrar deneyin."
            }
        } catch {
            let msg = mapStoreError(error)
            print("❌ Product load error:", msg)
            purchaseError = "Ürün bilgileri alınamadı: \(msg)"
            products = []
        }
    }
    
    // MARK: - Purchase
    func purchase(product: StoreKit.Product) async {
        purchaseError = nil
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                do {
                    let transaction = try Self.checkVerified(verification)
                    await applyEntitlements(from: transaction)
                    await transaction.finish()
                } catch {
                    let msg = mapStoreError(error)
                    print("❌ Verification error:", msg)
                    purchaseError = "Satın alma doğrulanamadı: \(msg)"
                }
                
            case .userCancelled:
                // Kullanıcı iptal etti → mesaj göstermeyebilirsin
                break
                
            case .pending:
                purchaseError = "Satın alma beklemede. Lütfen işlemi tamamlayın."
                
            @unknown default:
                purchaseError = "Satın alma tamamlanamadı. Lütfen tekrar deneyin."
            }
            
        } catch {
            let msg = mapStoreError(error)
            print("❌ Purchase error:", msg)
            purchaseError = "Satın alma başarısız: \(msg)"
        }
        
        await refreshEntitlements()
    }
    
    // MARK: - Entitlements
    func refreshEntitlements() async {
        var active = false
        
        for await result in StoreKit.Transaction.currentEntitlements {
            do {
                let transaction = try Self.checkVerified(result)
                if Self.productIDs.contains(transaction.productID) {
                    active = true
                    break
                }
            } catch {
                // doğrulanamayan entitlement'ı es geç
            }
        }
        
        isSubscribed = active
        print("ℹ️ isSubscribed:", active)
    }
    
    // MARK: - Restore
    func restore() async {
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }
        
        do {
            try await StoreKit.AppStore.sync()
        } catch {
            let msg = mapStoreError(error)
            print("❌ Restore error:", msg)
            purchaseError = "Geri yükleme başarısız: \(msg)"
        }
        
        await refreshEntitlements()
    }
    
    // MARK: - Observe Transactions
    private func observeTransactions() {
        Task.detached(priority: .background) { [weak self] in
            guard let self else { return }

            for await update in Transaction.updates {
                do {
                    let transaction = try Self.checkVerified(update)
                    await self.applyEntitlements(from: transaction)
                    await self.refreshEntitlements()
                    await transaction.finish()
                } catch {
                    let msg = await MainActor.run { self.mapStoreError(error) }
                    print("❌ Transaction update error:", msg)
                    await MainActor.run { self.purchaseError = "Satın alma doğrulanamadı: \(msg)" }
                }
            }
        }
    }
    
    // MARK: - Entitlement Apply
    private func applyEntitlements(from transaction: StoreKit.Transaction) async {
        if Self.productIDs.contains(transaction.productID) {
            isSubscribed = true
        }
    }
    
    // MARK: - Verification
    private nonisolated static func checkVerified<T>(
        _ result: StoreKit.VerificationResult<T>
    ) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Error Mapping (Review cihazında gelen gerçek hatayı yakalamak için)
    private func mapStoreError(_ error: Error) -> String {
        if let storeKitError = error as? StoreKitError {
            return "StoreKitError: \(storeKitError.localizedDescription)"
        }
        if let skError = error as? SKError {
            return "SKError(\(skError.code.rawValue)): \(skError.localizedDescription)"
        }
        return error.localizedDescription
    }
}

