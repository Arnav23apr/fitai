import SwiftUI

struct TourAnchorModifier: ViewModifier {
    let id: TourAnchorID
    @Environment(TourManager.self) private var tourManager

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            tourManager.registerAnchor(id, frame: geo.frame(in: .global))
                        }
                        .onChange(of: geo.frame(in: .global)) { _, newFrame in
                            tourManager.registerAnchor(id, frame: newFrame)
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
