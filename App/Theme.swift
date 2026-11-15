import SwiftUI

enum Theme {
    static let blue = Color(red: 0.31, green: 0.56, blue: 0.97)
    static let pink = Color(red: 0.97, green: 0.44, blue: 0.66)
    static let deepIndigo = Color(red: 0.08, green: 0.09, blue: 0.24)
    static let deepPlum = Color(red: 0.27, green: 0.09, blue: 0.30)

    static let accent = LinearGradient(
        colors: [blue, pink],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let background = LinearGradient(
        colors: [deepIndigo, deepPlum],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct GradientBackground: View {
    var body: some View {
        ZStack {
            Theme.background
            Circle()
                .fill(Theme.blue.opacity(0.35))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: -140, y: -280)
            Circle()
                .fill(Theme.pink.opacity(0.30))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: 150, y: 300)
        }
        .ignoresSafeArea()
    }
}
