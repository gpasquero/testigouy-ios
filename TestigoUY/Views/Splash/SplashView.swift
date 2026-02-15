import SwiftUI

struct SplashView: View {
    @State private var showIcon = false
    @State private var showText = false
    @State private var showTagline = false
    @State private var finished = false

    let onFinished: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // App icon
                Image("AppIconImage")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .shadow(color: Color("AccentColor").opacity(0.4), radius: 20, y: 4)
                    .scaleEffect(showIcon ? 1.0 : 0.5)
                    .opacity(showIcon ? 1.0 : 0.0)

                // Brand name
                VStack(spacing: 6) {
                    Text("testigo")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    + Text("UY")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(Color("AccentColor"))
                }
                .opacity(showText ? 1.0 : 0.0)
                .offset(y: showText ? 0 : 10)

                // Tagline
                Text("Disfrutá de la tranquilidad simple.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .opacity(showTagline ? 1.0 : 0.0)
                    .offset(y: showTagline ? 0 : 8)

                Spacer()

                // Subtle bottom indicator
                ProgressView()
                    .tint(Color("AccentColor"))
                    .opacity(showTagline && !finished ? 0.6 : 0.0)
                    .padding(.bottom, 60)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                showIcon = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                showText = true
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.6)) {
                showTagline = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                finished = true
                onFinished()
            }
        }
    }
}
