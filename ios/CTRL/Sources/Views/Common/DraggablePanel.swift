import SwiftUI

/// Panel lateral con handle de arrastre para cerrar deslizando.
/// `edge`: el lado desde el que aparece (.leading o .trailing).
struct DraggablePanel<Content: View>: View {
    let edge: HorizontalEdge
    let width: CGFloat
    @Binding var isPresented: Bool
    @ViewBuilder let content: () -> Content

    @State private var dragOffset: CGFloat = 0

    private var threshold: CGFloat { width * 0.35 }

    var body: some View {
        HStack(spacing: 0) {
            if edge == .trailing { Spacer() }

            HStack(spacing: 0) {
                if edge == .trailing {
                    handle
                }

                content()
                    .frame(width: width)

                if edge == .leading {
                    handle
                }
            }
            .offset(x: clampedOffset)
            .gesture(dragGesture)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 8)

            if edge == .leading { Spacer() }
        }
        .padding(.horizontal, 8)
        .padding(.top, 56)
    }

    private var handle: some View {
        VStack {
            Spacer()
            RoundedRectangle(cornerRadius: 3)
                .fill(.secondary.opacity(0.5))
                .frame(width: 5, height: 48)
            Spacer()
        }
        .frame(width: 16)
        .contentShape(Rectangle())
    }

    private var clampedOffset: CGFloat {
        switch edge {
        case .leading:
            return min(0, dragOffset)   // solo permite arrastrar hacia la izquierda
        case .trailing:
            return max(0, dragOffset)   // solo permite arrastrar hacia la derecha
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation.width
            }
            .onEnded { value in
                let shouldClose: Bool
                switch edge {
                case .leading:
                    shouldClose = value.translation.width < -threshold ||
                                  value.predictedEndTranslation.width < -threshold
                case .trailing:
                    shouldClose = value.translation.width > threshold ||
                                  value.predictedEndTranslation.width > threshold
                }

                withAnimation(.easeOut(duration: 0.2)) {
                    if shouldClose {
                        isPresented = false
                    }
                    dragOffset = 0
                }
            }
    }
}
