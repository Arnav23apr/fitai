import SwiftUI

struct PullUpBarIcon: View {
    var color: Color = .white

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let barThickness = h * 0.12
            let postWidth = w * 0.1
            let postHeight = h * 0.55
            let barY = h * 0.1
            let bracketHeight = h * 0.18

            var topBar = Path()
            topBar.addRoundedRect(in: CGRect(x: 0, y: barY, width: w, height: barThickness), cornerSize: CGSize(width: barThickness / 2, height: barThickness / 2))
            context.fill(topBar, with: .color(color))

            let leftX = w * 0.18
            var leftPost = Path()
            leftPost.addRoundedRect(in: CGRect(x: leftX - postWidth / 2, y: barY + barThickness, width: postWidth, height: postHeight), cornerSize: CGSize(width: 2, height: 2))
            context.fill(leftPost, with: .color(color))

            let rightX = w * 0.82
            var rightPost = Path()
            rightPost.addRoundedRect(in: CGRect(x: rightX - postWidth / 2, y: barY + barThickness, width: postWidth, height: postHeight), cornerSize: CGSize(width: 2, height: 2))
            context.fill(rightPost, with: .color(color))

            let bracketY = barY + barThickness + postHeight
            var leftBracket = Path()
            leftBracket.addRoundedRect(in: CGRect(x: leftX - w * 0.14, y: bracketY, width: w * 0.28, height: bracketHeight), cornerSize: CGSize(width: 3, height: 3))
            context.fill(leftBracket, with: .color(color))

            var rightBracket = Path()
            rightBracket.addRoundedRect(in: CGRect(x: rightX - w * 0.14, y: bracketY, width: w * 0.28, height: bracketHeight), cornerSize: CGSize(width: 3, height: 3))
            context.fill(rightBracket, with: .color(color))
        }
    }
}
