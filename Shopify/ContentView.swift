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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                withAnimation(.easeOut(duration: 0.2)) {
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
            Image("ShopifyLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 88, height: 88)
        }
    }
}
