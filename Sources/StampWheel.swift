import SwiftUI

/// A physical-feeling number drum, like the wheel on a date stamp.
/// Drag up or down to roll it; it clicks into place on release.
struct StampDrum: View {
    let title: String
    let labels: [String]
    @Binding var selection: Int
    var width: CGFloat? = 72
    var height: CGFloat = 112

    @State private var dragBase: Int? = nil
    @State private var frac: CGFloat = 0

    var body: some View {
        let count = labels.count
        let sel = min(max(selection, 0), max(count - 1, 0))
        let step = height / 3.6
        let radius = step / 0.55
        let pos = CGFloat(sel) + frac
        let lo = max(0, Int(floor(pos)) - 3)
        let hi = min(count - 1, Int(ceil(pos)) + 3)
        let idxs: [Int] = lo <= hi ? Array(lo...hi) : []

        VStack(spacing: 3) {
            if !title.isEmpty {
                Text(title)
                    .font(.caption2.bold())
                    .foregroundColor(GC.dim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: width ?? .infinity)
            }
            ZStack {
                // Drum body: bright in the middle, dark where it curves away.
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(
                        colors: [Color(white: 0.30), Color(white: 0.93), Color(white: 0.99), Color(white: 0.90), Color(white: 0.28)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))

                ForEach(idxs, id: \.self) { i in
                    let theta = (CGFloat(i) - pos) * 0.55
                    let visible = abs(theta) < 1.45
                    let label = labels[i]
                    Text(label)
                        .font(.system(size: label.count > 3 ? step * 0.62 : step * 0.98, weight: .black, design: .rounded))
                        .foregroundColor(Color(white: 0.10))
                        .shadow(color: Color.white.opacity(0.7), radius: 0, x: 0, y: 1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(.horizontal, 8)
                        .scaleEffect(x: 1, y: max(cos(theta), 0.05))
                        .offset(y: radius * sin(theta))
                        .opacity(visible ? Double(max(cos(theta), 0)) : 0)
                }

                // Curvature shading
                LinearGradient(
                    stops: [
                        Gradient.Stop(color: Color.black.opacity(0.55), location: 0.0),
                        Gradient.Stop(color: Color.clear, location: 0.30),
                        Gradient.Stop(color: Color.clear, location: 0.70),
                        Gradient.Stop(color: Color.black.opacity(0.55), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)

                // Reading marks
                HStack {
                    Image(systemName: "arrowtriangle.right.fill")
                        .font(.system(size: 8))
                        .foregroundColor(Color.red)
                    Spacer()
                    Image(systemName: "arrowtriangle.left.fill")
                        .font(.system(size: 8))
                        .foregroundColor(Color.red)
                }
                .padding(.horizontal, 2)
                .allowsHitTesting(false)
            }
            .frame(maxWidth: width ?? .infinity)
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        LinearGradient(
                            colors: [Color(white: 0.85), Color(white: 0.35), Color(white: 0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 3
                    )
            )
            .shadow(color: Color.black.opacity(0.5), radius: 3, x: 0, y: 2)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { g in
                        if dragBase == nil { dragBase = sel }
                        let base = dragBase ?? sel
                        let raw = CGFloat(base) - g.translation.height / step
                        let upper = CGFloat(max(count - 1, 0))
                        let clamped = min(max(raw, 0), upper)
                        let newSel = Int(clamped.rounded())
                        if newSel != selection { selection = newSel }
                        frac = clamped - CGFloat(newSel)
                    }
                    .onEnded { _ in
                        dragBase = nil
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            frac = 0
                        }
                    }
            )
            .sensoryFeedback(.selection, trigger: selection)
        }
    }
}

struct StampWheel: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var width: CGFloat? = 72
    var height: CGFloat = 112

    var body: some View {
        let labels: [String] = range.map { String($0) }
        StampDrum(
            title: title,
            labels: labels,
            selection: Binding<Int>(
                get: { min(max(value - range.lowerBound, 0), labels.count - 1) },
                set: { value = $0 + range.lowerBound }
            ),
            width: width,
            height: height
        )
        .onChange(of: range.upperBound) { _, newUpper in
            if value > newUpper { value = newUpper }
        }
    }
}
