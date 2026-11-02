import SwiftUI

// Google Material Symbols, bedtime (Apache 2.0): контур — режим выключен, заливка — включен.
func moon(filled: Bool, size: CGFloat = 18) -> NSImage {
    let path = filled
        ? "M524-40q-84 0-157.5-32t-128-86.5Q184-213 152-286.5T120-444q0-146 93-257.5T450-840q-18 99 11 193.5T561-481q71 71 165.5 100T920-370q-26 144-138 237T524-40Z"
        : "M524-40q-84 0-157.5-32t-128-86.5Q184-213 152-286.5T120-444q0-146 93-257.5T450-840q-18 99 11 193.5T561-481q71 71 165.5 100T920-370q-26 144-138 237T524-40Zm0-80q88 0 163-44t118-121q-86-8-163-43.5T504-425q-61-61-97-138t-43-163q-77 43-120.5 118.5T200-444q0 135 94.5 229.5T524-120Zm-20-305Z"
    let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" height=\"24\" viewBox=\"0 -960 960 960\" width=\"24\"><path d=\"\(path)\"/></svg>"
    let image = NSImage(data: Data(svg.utf8)) ?? NSImage()
    image.size = NSSize(width: size, height: size)
    image.isTemplate = true
    return image
}

struct PanelView: View {
    @ObservedObject var night: NightMode

    var body: some View {
        PanelContent(isOn: night.isOn, toggle: night.toggle,
                     screenDim: $night.screenDim, keyboardDim: $night.keyboardDim)
    }
}

struct PanelContent: View {
    let isOn: Bool
    let toggle: () -> Void
    @Binding var screenDim: Double
    @Binding var keyboardDim: Double

    var body: some View {
        VStack(spacing: 16) {
            PowerButton(isOn: isOn, action: toggle)
            VStack(spacing: 14) {
                LevelSlider(title: "Экран", value: $screenDim, range: NightMode.screenRange)
                LevelSlider(title: "Клавиатура", value: $keyboardDim, range: NightMode.keyboardRange)
            }
            .opacity(isOn ? 1 : 0.65)
            HStack {
                Spacer()
                Button("Выйти") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 300)
    }
}

private struct PowerButton: View {
    let isOn: Bool
    let action: () -> Void
    @State private var isHovered = false

    private var fill: Color {
        isOn ? .indigo : .primary.opacity(isHovered ? 0.13 : 0.08)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(nsImage: moon(filled: isOn, size: 30))
                    .renderingMode(.template)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ночной режим")
                        .font(.system(size: 15, weight: .semibold))
                    Text(isOn ? "Включен" : "Выключен")
                        .font(.system(size: 13))
                        .opacity(0.8)
                }
                Spacer(minLength: 0)
                PowerIndicator(isOn: isOn)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 76)
            .foregroundStyle(isOn ? Color.white : Color.primary)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(fill))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressStyle())
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.18), value: isOn)
        .accessibilityLabel("Ночной режим")
        .accessibilityValue(isOn ? "Включен" : "Выключен")
    }
}

private struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

private struct PowerIndicator: View {
    let isOn: Bool

    var body: some View {
        Capsule()
            .fill(isOn ? Color.white.opacity(0.3) : Color.primary.opacity(0.18))
            .frame(width: 46, height: 28)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
                    .padding(3)
            }
    }
}

private struct LevelSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    // Вправо светлее, как у обычной яркости: край справа — системный минимум.
    // Шаг 5% здесь, а не в Slider: со step он рисует точки-деления под дорожкой.
    private var position: Binding<Double> {
        Binding(get: { -value }, set: { value = abs(($0 / 0.05).rounded() * 0.05) })
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Text(value < 0.005 ? "минимум" : "−\(Int((value * 100).rounded()))%")
                    .font(.system(size: 13).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: position, in: -range.upperBound...(-range.lowerBound))
                .labelsHidden()
                .accessibilityLabel(title)
        }
    }
}
