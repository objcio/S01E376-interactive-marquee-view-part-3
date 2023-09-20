//

import SwiftUI

extension View {
    func measureWidth(_ onChange: @escaping (CGFloat) -> ()) -> some View {
        background {
            GeometryReader { proxy in
                let width = proxy.size.width
                Color.clear
                    .onAppear {
                        onChange(width)
                    }.onChange(of: width) {
                        onChange($0)
                    }
            }
        }
    }
}

struct MarqueeModel {
    var contentWidth: CGFloat? = nil
    var offset: CGFloat = 0
    var dragStartOffset: CGFloat? = nil
    var dragTranslation: CGFloat = 0
    var currentVelocity: CGFloat = 0

    var previousTick: Date = .now
    var targetVelocity: Double
    var spacing: CGFloat
    init(targetVelocity: Double, spacing: CGFloat) {
        self.targetVelocity = targetVelocity
        self.spacing = spacing
    }

    mutating func tick(at time: Date) {
        let delta = time.timeIntervalSince(previousTick)
        defer { previousTick = time }
        currentVelocity += (targetVelocity - currentVelocity) * delta * 3
        if let dragStartOffset {
            offset = dragStartOffset + dragTranslation
        } else {
            offset -= delta * currentVelocity
        }
        if let c = contentWidth {
            offset.formTruncatingRemainder(dividingBy: c + spacing)
            while offset > 0 {
                offset -= c + spacing
            }

        }
    }

    mutating func dragChanged(_ value: DragGesture.Value) {
        if dragStartOffset == nil {
            dragStartOffset = offset
        }
        dragTranslation = value.translation.width
    }

    mutating func dragEnded(_ value: DragGesture.Value) {
        offset = dragStartOffset! + value.translation.width
        dragStartOffset = nil
        currentVelocity = -value.velocity.width
    }

}

struct Marquee<Content: View>: View {
    @ViewBuilder var content: Content
    @State private var containerWidth: CGFloat? = nil
    @State private var model: MarqueeModel
    private var targetVelocity: Double
    private var spacing: CGFloat

    init(targetVelocity: Double, spacing: CGFloat = 10, @ViewBuilder content: () -> Content) {
        self.content = content()
        self._model = .init(wrappedValue: MarqueeModel(targetVelocity: targetVelocity, spacing: spacing))
        self.targetVelocity = targetVelocity
        self.spacing = spacing
    }

    var extraContentInstances: Int {
        let contentPlusSpacing = ((model.contentWidth ?? 0) + model.spacing)
        guard contentPlusSpacing != 0 else { return 1 }
        return Int(((containerWidth ?? 0) / contentPlusSpacing).rounded(.up))
    }

    var body: some View {
        TimelineView(.animation) { context in
            HStack(spacing: model.spacing) {
                HStack(spacing: model.spacing) {
                    content
                }
                .measureWidth { model.contentWidth = $0 }
                ForEach(Array(0..<extraContentInstances), id: \.self) { _ in
                    content
                }
            }
            .offset(x: model.offset)
            .fixedSize()
            .onChange(of: context.date) { newDate in
                model.tick(at: newDate)
            }
        }
        .measureWidth { containerWidth = $0 }
        .gesture(dragGesture)
        .onAppear { model.previousTick = .now }
        .onChange(of: targetVelocity) {
            model.targetVelocity = $0
        }
        .onChange(of: spacing) {
            model.spacing = $0
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }

    var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                model.dragChanged(value)
            }.onEnded { value in
                model.dragEnded(value)
            }
    }
}

struct ContentView: View {
    @State var velocity: CGFloat = 50
    @State var numberOfItems: Double = 5
    var body: some View {
        VStack {
            Slider(value: $velocity, in: -300...300, label: { Text("Velocity") })
            Slider(value: $numberOfItems, in: 1...20, label: { Text("Number Of Items")})

            Marquee(targetVelocity: velocity) {
                ForEach(Array(0..<(Int(numberOfItems))), id: \.self) { i in
                    Text("Item \(i)")
                        .padding()
                        .foregroundColor(.white)
                        .background {
                            Capsule()
                                .fill(.blue)
                        }
                }
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ContentView()
}
