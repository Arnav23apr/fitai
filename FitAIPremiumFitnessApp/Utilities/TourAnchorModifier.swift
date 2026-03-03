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
                            let frame = geo.frame(in: .global)
                            tourManager.registerAnchor(id, frame: frame)
                        }
                        .onChange(of: geo.frame(in: .global)) { _, newFrame in
                            tourManager.registerAnchor(id, frame: newFrame)
                        }
                        .onChange(of: tourManager.isActive) { _, active in
                            if active {
                                tourManager.registerAnchor(id, frame: geo.frame(in: .global))
                            }
                        }
                        .onChange(of: tourManager.currentStepIndex) { _, _ in
                            if tourManager.isActive {
                                tourManager.registerAnchor(id, frame: geo.frame(in: .global))
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
