//
//  CodeRainEffect.swift
//  ClaudeGlance
//
//  代码雨粒子特效 (可选装饰)
//

import SwiftUI

struct CodeRainEffect: View {
    @State private var particles: [CodeParticle] = []
    private let maxParticles = 30

    private let characters = ["0", "1", "{", "}", ";", "=", "→", "<", ">", "/", "*", "+"]

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05)) { timeline in
            Canvas { context, size in
                updateParticles(size: size, date: timeline.date)

                for particle in particles {
                    let text = Text(particle.character)
                        .font(.system(size: particle.size, design: .monospaced))
                        .foregroundColor(.green)

                    context.opacity = particle.opacity
                    context.draw(
                        text,
                        at: CGPoint(x: particle.x, y: particle.y)
                    )
                }
            }
        }
    }

    private func updateParticles(size: CGSize, date: Date) {
        // 移动现有粒子
        particles = particles.compactMap { particle in
            var p = particle
            p.y += p.speed
            p.opacity -= 0.015

            if p.opacity <= 0 || p.y > size.height {
                return nil
            }
            return p
        }

        // 随机添加新粒子
        if particles.count < maxParticles && Int.random(in: 0...3) == 0 {
            let newParticle = CodeParticle(
                character: characters.randomElement()!,
                x: CGFloat.random(in: 0...size.width),
                y: 0,
                speed: CGFloat.random(in: 1...3),
                opacity: Double.random(in: 0.5...1.0),
                size: CGFloat.random(in: 8...12)
            )
            particles.append(newParticle)
        }
    }
}

struct CodeParticle: Identifiable {
    let id = UUID()
    var character: String
    var x: CGFloat
    var y: CGFloat
    var speed: CGFloat
    var opacity: Double
    var size: CGFloat
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.black
        CodeRainEffect()
    }
    .frame(width: 320, height: 200)
}
