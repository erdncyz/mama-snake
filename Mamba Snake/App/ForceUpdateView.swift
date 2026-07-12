import SwiftUI

/// Remote Config'den `force_update_required = true` geldiğinde
/// kullanıcıya gösterilen tam ekran güncelleme ekranı.
struct ForceUpdateView: View {

    /// App Store ürün sayfası URL'i (Bundle ID üzerinden oluşturulur;
    /// gerçek ID öğrenildiğinde buraya yazılabilir).
    private let appStoreURL = URL(
        string: "https://apps.apple.com/app/id6746047498")!

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.08, blue: 0.12)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // İkon
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green, Color(red: 0.0, green: 0.7, blue: 0.4)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: .green.opacity(0.4), radius: 20)

                VStack(spacing: 12) {
                    Text("Güncelleme Gerekiyor")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)

                    Text("Bu sürüm artık desteklenmiyor.\nDevam etmek için lütfen uygulamayı güncelleyin.")
                        .font(.callout)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Button {
                    UIApplication.shared.open(appStoreURL)
                } label: {
                    Label("App Store'da Güncelle", systemImage: "arrow.up.forward.app.fill")
                        .font(.headline.weight(.bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: 280)
                        .padding(.vertical, 16)
                        .background(Color.green)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .green.opacity(0.4), radius: 10)
                }

                Spacer()

                Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.bottom, 20)
            }
        }
    }
}

#Preview {
    ForceUpdateView()
}
