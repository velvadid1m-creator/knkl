import SwiftUI

struct ContentView: View {
    @State private var showSplash = true

    var body: some View {
        ZStack {
            DashboardShell()

            if showSplash {
                ShopifySplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                withAnimation(.easeOut(duration: 0.25)) {
                    showSplash = false
                }
            }
        }
    }
}

private struct ShopifySplashView: View {
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(ShopifyTheme.brandDark)
                        .frame(width: 72, height: 72)
                    Image(systemName: "bag.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text("Shopify")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(ShopifyTheme.text)
            }
        }
    }
}
