import SwiftUI

struct TourAnchorModifier: ViewModifier {
    let id: TourAnchorID
    @Environment(TourManager.self) private var tourManager

    func body(content: Content) -> some View {
        content
            .id(id.rawValue)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            let frame = geo.frame(in: .named("tourRoot"))
                            tourManager.registerAnchor(id, frame: frame)
                        }
                        .onChange(of: geo.frame(in: .named("tourRoot"))) { _, newFrame in
                            tourManager.registerAnchor(id, frame: newFrame)
                        }
                        .onChange(of: tourManager.isActive) { _, active in
                            if active {
                                tourManager.registerAnchor(id, frame: geo.frame(in: .named("tourRoot")))
                            }
                        }
                        .onChange(of: tourManager.currentStepIndex) { _, _ in
                            if tourManager.isActive {
                                tourManager.registerAnchor(id, frame: geo.frame(in: .named("tourRoot")))
                            }
                        }
                }
            )
    }
}

extension View {
    func tourAnchor(_ id: TourAnchorID) -> some View {
        modifier(TourAnchorModifier(id: id))
    }
}
