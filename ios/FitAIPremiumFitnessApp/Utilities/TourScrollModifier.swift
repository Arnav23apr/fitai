import SwiftUI

struct TourScrollModifier: ViewModifier {
    @Environment(TourManager.self) private var tourManager
    let tabIndex: Int
    let proxy: ScrollViewProxy

    func body(content: Content) -> some View {
        content
            .onChange(of: tourManager.scrollToAnchor) { _, anchor in
                guard let anchor,
                      let step = tourManager.currentStep,
                      step.targetTab == tabIndex else { return }
                withAnimation(.easeInOut(duration: 0.4)) {
                    proxy.scrollTo(anchor.rawValue, anchor: .center)
                }
                Task {
                    try? await Task.sleep(for: .milliseconds(450))
                    tourManager.scrollToAnchor = nil
                }
            }
    }
}

extension View {
    func tourAutoScroll(tab: Int, proxy: ScrollViewProxy) -> some View {
        modifier(TourScrollModifier(tabIndex: tab, proxy: proxy))
    }
}
