import SwiftUI

/// The numbers on the drum. Animatable so a flick rolls through every value on the way.
struct DrumFace: View, Animatable {
    var pos: Double
    let labels: [String]
    let step: CGFloat
    let radius: CGFloat

    var animatableData: Double {
        get { pos }
        set { pos = newValue }
    }

    var body: some View {
        let count = labels.count
        let lo = max(0, Int(floor(pos)) - 3)
        let hi = min(count - 1, Int(ceil(pos)) + 3)
        let idxs: [Int] = lo <= hi ? Array(lo...hi) : []
        ZStack {
            ForEach(idxs, id: \.self) { i in
                let theta = (CGFloat(i) - CGFloat(pos)) * 0.55
                let visible = abs(theta) < 1.45
                let label = labels[i]
                Text(label)
                    .font(.system(size: label.count > 3 ? step * 0.6 : step * 1.0, weight: .black, design: .serif))
                    .foregroundColor(GC.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 10)
                    .scaleEffect(x: 1, y: max(cos(theta), 0.05))
                    .offset(y: radius * sin(theta))
                    .opacity(visible ? Double(max(cos(theta), 0)) : 0)
            }
        }
    }
}

/// A date-stamp style drum: steel housing, cream rubber band with numerals,
/// knurled thumb edges. Drag to roll it, flick for momentum, it clicks into place.
struct StampDrum: View {
    let title: String
    let labels: [String]
    @Binding var selection: Int
    var width: CGFloat?
    var height: CGFloat
    var seat: Int = 0

    @State private var pos: Double
    @State private var dragBase: Int? = nil

    init(title: String, labels: [String], selection: Binding<Int>, width: CGFloat? = 72, height: CGFloat = 112, seat: Int = 0) {
        self.seat = seat
        self.title = title
        self.labels = labels
        self._selection = selection
        self.width = width
        self.height = height
        _pos = State(initialValue: Double(selection.wrappedValue))
    }

    private var step: CGFloat {
        return height / 3.4
    }

    var body: some View {
        let count = labels.count
        let sel = min(max(selection, 0), max(count - 1, 0))
        let radius = step / 0.55

        VStack(spacing: 3) {
            if !title.isEmpty {
                Text(title)
                    .font(.caption2.bold())
                    .foregroundColor(GC.dim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: width ?? .infinity)
            }
            HStack(spacing: 0) {
                knurl
                ZStack {
                    Rectangle()
                        .fill(tanColor(seat))
                    DrumFace(pos: pos, labels: labels, step: step, radius: radius)
                    VStack {
                        Rectangle().fill(GC.text.opacity(0.18)).frame(height: 1)
                        Spacer()
                        Rectangle().fill(GC.text.opacity(0.18)).frame(height: 1)
                    }
                    .padding(.vertical, height * 0.14)
                    .allowsHitTesting(false)
                    // Reading line
                    Rectangle()
                        .fill(GC.red.opacity(0.7))
                        .frame(height: 1)
                        .allowsHitTesting(false)
                    HStack {
                        Image(systemName: "arrowtriangle.right.fill")
                            .font(.system(size: 9))
                            .foregroundColor(GC.red)
                        Spacer()
                        Image(systemName: "arrowtriangle.left.fill")
                            .font(.system(size: 9))
                            .foregroundColor(GC.red)
                    }
                    .padding(.horizontal, 2)
                    .allowsHitTesting(false)
                }
                .frame(maxWidth: .infinity)
                knurl
            }
            .frame(maxWidth: width ?? .infinity)
            .frame(height: height)
            .background(RoundedRectangle(cornerRadius: 12).fill(seatColors[((seat % 8) + 8) % 8]))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { g in
                        if dragBase == nil { dragBase = sel }
                        let base = dragBase ?? sel
                        let raw = CGFloat(base) - g.translation.height / step
                        let upper = CGFloat(max(count - 1, 0))
                        let clamped = min(max(raw, 0), upper)
                        pos = Double(clamped)
                        let newSel = Int(clamped.rounded())
                        if newSel != selection { selection = newSel }
                    }
                    .onEnded { g in
                        let base = dragBase ?? sel
                        dragBase = nil
                        let predicted = CGFloat(base) - g.predictedEndTranslation.height / step
                        let upper = CGFloat(max(count - 1, 0))
                        let target = Int(min(max(predicted, 0), upper).rounded())
                        selection = target
                        withAnimation(.easeOut(duration: 0.55)) {
                            pos = Double(target)
                        }
                    }
            )
            .sensoryFeedback(.selection, trigger: selection)
            .onChange(of: selection) { _, newValue in
                if dragBase == nil {
                    withAnimation(.easeOut(duration: 0.25)) {
                        pos = Double(min(max(newValue, 0), max(count - 1, 0)))
                    }
                }
            }
            .onChange(of: labels.count) { _, newCount in
                if Int(pos.rounded()) > newCount - 1 {
                    pos = Double(max(newCount - 1, 0))
                }
            }
        }
    }

    /// Ribbed thumb edge on the side of the drum.
    private var knurl: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(seatColors[((seat % 8) + 8) % 8]))
            var y: CGFloat = 2
            while y < size.height {
                var p = Path()
                p.move(to: CGPoint(x: 1, y: y))
                p.addLine(to: CGPoint(x: size.width - 1, y: y))
                ctx.stroke(p, with: .color(Color.black.opacity(0.28)), lineWidth: 1)
                y += 4
            }
        }
        .frame(width: 9)
    }
}

struct StampWheel: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var width: CGFloat? = 72
    var height: CGFloat = 112
    var seat: Int = 0

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
            height: height,
            seat: seat
        )
        .onChange(of: range.upperBound) { _, newUpper in
            if value > newUpper { value = newUpper }
        }
    }
}
