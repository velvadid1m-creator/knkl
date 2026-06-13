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

/// Matches real Shopify app launch — green bag only, no text.
private struct ShopifySplashView: View {
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(ShopifyTheme.brandDark)
                    .frame(width: 80, height: 80)
                ShopifySplashBagShape()
                    .fill(.white)
                    .frame(width: 42, height: 42)
            }
        }
    }
}

private struct ShopifySplashBagShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.24, y: h * 0.36))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.76, y: h * 0.36),
            control: CGPoint(x: w * 0.5, y: h * 0.08)
        )
        path.addLine(to: CGPoint(x: w * 0.86, y: h * 0.88))
        path.addQuadCurve(
            to: CGPoint(x: w * 0.14, y: h * 0.88),
            control: CGPoint(x: w * 0.5, y: h * 1.02)
        )
        path.closeSubpath()
        return path
    }
}
