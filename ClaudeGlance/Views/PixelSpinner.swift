//
//  PixelSpinner.swift
//  ClaudeGlance
//
//  像素艺术风格的状态动画图标
//  4x4 网格，不同状态展示不同动画效果
//

import SwiftUI

struct PixelSpinner: View {
    let status: SessionStatus
    private let gridSize = 4
    private let pixelGap: CGFloat = 2

    @State private var pixelStates: [[Double]] = Array(
        repeating: Array(repeating: 0.3, count: 4),
        count: 4
    )
    @State private var animationPhase: Double = 0

    private var baseColor: Color {
        switch status {
        case .idle:
            return .gray
        case .reading:
            return .cyan
        case .thinking:
            return .orange
        case .writing:
            return .purple
        case .waiting:
            return .yellow
        case .completed:
            return .green
        case .error:
            return .red
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: animationInterval)) { timeline in
            Canvas { context, size in
                let pixelSize = (size.width - CGFloat(gridSize - 1) * pixelGap) / CGFloat(gridSize)

                for row in 0..<gridSize {
                    for col in 0..<gridSize {
                        let opacity = calculateOpacity(row: row, col: col, date: timeline.date)

                        let x = CGFloat(col) * (pixelSize + pixelGap)
                        let y = CGFloat(row) * (pixelSize + pixelGap)

                        let rect = CGRect(x: x, y: y, width: pixelSize, height: pixelSize)
                        let path = RoundedRectangle(cornerRadius: 2).path(in: rect)

                        context.fill(path, with: .color(baseColor.opacity(opacity)))
                    }
                }
            }
        }
    }

    private var animationInterval: Double {
        switch status {
        case .thinking:
            return 0.06
        case .reading, .writing:
            return 0.1
        case .waiting:
            return 0.15
        case .completed, .error:
            return 0.5
        case .idle:
            return 0.2
        }
    }

    private func calculateOpacity(row: Int, col: Int, date: Date) -> Double {
        let time = date.timeIntervalSinceReferenceDate

        switch status {
        case .idle:
            // 缓慢呼吸
            return 0.2 + 0.2 * (sin(time * 1.5) + 1) / 2

        case .reading:
            // 水平波浪流动（从左到右）
            let phase = time * 4
            let wave = sin(phase - Double(col) * 0.8)
            return 0.3 + 0.7 * (wave + 1) / 2

        case .thinking:
            // 随机快速闪烁
            let seed = Double(row * 4 + col)
            let flicker = sin(time * 12 + seed * 2.5) * cos(time * 8 + seed * 1.7)
            return 0.2 + 0.8 * (flicker + 1) / 2

        case .writing:
            // 从上到下填充效果
            let phase = time * 3
            let fillProgress = (sin(phase) + 1) / 2 * Double(gridSize)
            let rowProgress = fillProgress - Double(row)
            return min(1.0, max(0.2, rowProgress))

        case .waiting:
            // 脉冲呼吸，从中心向外
            let centerX = Double(gridSize - 1) / 2
            let centerY = Double(gridSize - 1) / 2
            let distance = sqrt(pow(Double(col) - centerX, 2) + pow(Double(row) - centerY, 2))
            let maxDistance = sqrt(2) * centerX
            let normalizedDist = distance / maxDistance

            let pulse = sin(time * 2 - normalizedDist * 2)
            return 0.3 + 0.7 * (pulse + 1) / 2

        case .completed:
            // 对勾图案 ✓
            let checkPattern: [[Bool]] = [
                [false, false, false, true],
                [false, false, true, false],
                [true, true, false, false],
                [false, true, false, false]
            ]
            let isCheck = checkPattern[row][col]
            let glow = 0.8 + 0.2 * sin(time * 2)
            return isCheck ? glow : 0.15

        case .error:
            // X 图案闪烁
            let isX = (row == col) || (row + col == gridSize - 1)
            let flash = sin(time * 6) > 0
            return isX ? (flash ? 1.0 : 0.4) : 0.1
        }
    }
}

// MARK: - Preview
#Preview("All States") {
    HStack(spacing: 20) {
        VStack {
            PixelSpinner(status: .idle)
                .frame(width: 32, height: 32)
            Text("Idle").font(.caption)
        }

        VStack {
            PixelSpinner(status: .reading)
                .frame(width: 32, height: 32)
            Text("Reading").font(.caption)
        }

        VStack {
            PixelSpinner(status: .thinking)
                .frame(width: 32, height: 32)
            Text("Thinking").font(.caption)
        }

        VStack {
            PixelSpinner(status: .writing)
                .frame(width: 32, height: 32)
            Text("Writing").font(.caption)
        }

        VStack {
            PixelSpinner(status: .waiting)
                .frame(width: 32, height: 32)
            Text("Waiting").font(.caption)
        }

        VStack {
            PixelSpinner(status: .completed)
                .frame(width: 32, height: 32)
            Text("Done").font(.caption)
        }

        VStack {
            PixelSpinner(status: .error)
                .frame(width: 32, height: 32)
            Text("Error").font(.caption)
        }
    }
    .padding()
    .background(Color.black)
}
