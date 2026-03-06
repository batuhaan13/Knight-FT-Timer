import SwiftUI
import StoreKit

struct PaywallView: View {
    @ObservedObject var subVM: SubscriptionViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) private var openURL

    @State private var showPurchaseToast: Bool = false

    private let privacyPolicyURL = URL(string: "https://batuhaan13.github.io/Knight-FT-Timer/")!
    private let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.08, blue: 0.2).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {

                    // MARK: - Header
                    VStack(spacing: 6) {
                        Text("👑")
                            .font(.system(size: 32))

                        Text("FT Timer Premium")
                            .font(.system(size: 30, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.70)

                        Text("Aylık otomatik yenilenen abonelik")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .multilineTextAlignment(.center)
                    .padding(.top, 28)

                    // MARK: - Pricing Card (Apple Guideline 3.1.2c Compliant)
                    PricingCard(displayPrice: subVM.currentProduct?.displayPrice)

                    // MARK: - Features
                    FeaturesSection()

                    // MARK: - Purchase area
                    if subVM.isLoading {
                        ProgressView("Ürün yükleniyor…")
                            .tint(.white)
                            .padding(.top, 4)
                    } else {
                        if let product = subVM.currentProduct {
                            // CTA Button
                            Button(action: { Task { await subVM.purchaseCurrent() } }) {
                                VStack(spacing: 4) {
                                    Text("7 Gün Ücretsiz Başla")
                                        .font(.system(.title3, design: .rounded).bold())
                                    Text("Sonra \(product.displayPrice)/ay — İstediğin zaman iptal et")
                                        .font(.system(.footnote, design: .rounded).weight(.semibold))
                                        .foregroundColor(.white.opacity(0.85))
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue.opacity(0.9), Color.purple.opacity(0.85), Color.pink.opacity(0.8)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(14)
                            .disabled(subVM.isLoading)

                            // Legal Disclosures Box
                            LegalDisclosuresBox(displayPrice: product.displayPrice)

                        } else {
                            Button("Ürün yüklenemedi, tekrar dene") {
                                Task { await subVM.reloadProducts() }
                            }
                            .font(.system(.title3, design: .rounded).bold())
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue.opacity(0.9), Color.pink.opacity(0.8)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(14)
                            .disabled(subVM.isLoading)

                            // Fallback legal
                            LegalDisclosuresBox(displayPrice: "$2.99")
                        }
                    }

                    // MARK: - Restore Button
                    Button("Satın alımları geri yükle") {
                        Task { await subVM.restore() }
                    }
                    .font(.footnote.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .foregroundColor(.white.opacity(0.6))
                    .disabled(subVM.isLoading)

                    if let error = subVM.purchaseError {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // MARK: - Footer
                    VStack(spacing: 8) {
                        

                        Text("Devam ederek Şartlar ve Gizlilik Politikası'nı kabul etmiş olursunuz.")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.45))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 14) {
                            Button { openURL(termsOfUseURL) } label: {
                                Text("Terms of Use (EULA)")
                                    .font(.caption.weight(.semibold))
                                    .underline()
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                            }
                            Button { openURL(privacyPolicyURL) } label: {
                                Text("Privacy Policy")
                                    .font(.caption.weight(.semibold))
                                    .underline()
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                            }
                        }
                        .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.top, 4)

                    Spacer(minLength: 16)
                }
                .padding()
                .padding(.horizontal)
            }
        }
        // MARK: - Back button
        .overlay(alignment: .topLeading) {
            Button { dismiss() } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
            .padding(.leading, 16)
            .padding(.top, 12)
            .zIndex(999)
        }
        // MARK: - Purchase toast
        .overlay(alignment: .bottom) {
            if showPurchaseToast {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                    Text("Satın alma başarılı")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.black.opacity(0.75))
                        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                )
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onChange(of: subVM.isSubscribed) { _, newValue in
            if newValue {
                withAnimation(.spring()) { showPurchaseToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeInOut) { showPurchaseToast = false }
                }
            }
        }
        .onAppear {
            if subVM.currentProduct == nil && !subVM.isLoading {
                Task { await subVM.reloadProducts() }
            }
        }
        .foregroundColor(.white)
    }
}

// MARK: - Pricing Card
struct PricingCard: View {
    let displayPrice: String?
    private var price: String { displayPrice ?? "$2.99" }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.07))
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)

            VStack(spacing: 0) {
                // Ücretsiz deneme satırı
                HStack {
                    Text("Ücretsiz deneme süresi")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Text("7 gün")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(Color(red: 0.65, green: 0.70, blue: 1.0))
                }
                .padding(.bottom, 10)

                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 1)
                    .padding(.bottom, 10)

                // Deneme sonrası ücret satırı
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Deneme sonrası ücret")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white.opacity(0.6))
                        Text("Her ay otomatik yenilenir")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.4))
                    }
                    Spacer()
                    HStack(alignment: .lastTextBaseline, spacing: 1) {
                        Text(price)
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        Text("/ay")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.white.opacity(0.45))
                    }
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Features Section
struct FeaturesSection: View {
    private let features = [
        "Tüm FT dalga ve boss zamanlayıcıları",
        "Dalga başlangıçları için hassas geri sayım",
        "Kritik anlar için zamanında uyarılar",
        "Etkinlik boyunca kesintisiz takip ve kontrol"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PREMİUM İLE ŞUNLARI AÇARSIN:")
                .font(.footnote.weight(.bold))
                .foregroundColor(.white.opacity(0.7))
                .tracking(0.3)
                .padding(.bottom, 4)

            ForEach(features, id: \.self) { feature in
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.9), Color.purple, Color.pink.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 1)

                    Text(feature)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 3)
            }

            Text("Premium olmadan bu özellikler sınırlıdır.")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.45))
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Legal Disclosures Box
struct LegalDisclosuresBox: View {
    let displayPrice: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LegalItem {
                Text("**7 günlük ücretsiz deneme** bittikten sonra aboneliğiniz **\(displayPrice)/ay** olarak otomatik yenilenir.")
            }
            LegalItem {
                Text("Deneme süresi içinde iptal ederseniz **ücret alınmaz**.")
            }
            LegalItem {
                Text("İptal için: Ayarlar → Apple Kimliği → Abonelikler")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

struct LegalItem<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color(red: 0.55, green: 0.57, blue: 1.0))
                .frame(width: 5, height: 5)
                .padding(.top, 6)

            content
                .font(.footnote)
                .foregroundColor(.white.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
