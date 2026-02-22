import SwiftUI

struct ParticleEffectView: View {
    @Binding var trigger: Bool
    
    @State private var particles: [Particle] = []
    
    struct Particle: Hashable, Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var angle: Double
        var speed: Double
        var scale: CGFloat
        var color: Color
        var opacity: Double = 1.0
    }
    
    let colors: [Color] = [.red, .blue, .green, .yellow, .orange, .purple, .pink]
    
    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: 4, height: 4)
                    .scaleEffect(particle.scale)
                    .opacity(particle.opacity)
                    .position(x: particle.x, y: particle.y)
            }
        }
        .frame(width: 50, height: 50) // Constrain the effect area slightly
        .allowsHitTesting(false) // Let clicks pass through
        .onChange(of: trigger) { _, newValue in
            if newValue {
                explode()
            }
        }
    }
    
    func explode() {
        // Generate particles
        for _ in 0..<12 {
            let angle = Double.random(in: 0..<360)
            let speed = Double.random(in: 20...50) // Distance they travel
            let scale = CGFloat.random(in: 0.5...1.2)
            let color = colors.randomElement()!
            
            particles.append(Particle(x: 25, y: 25, angle: angle, speed: speed, scale: scale, color: color)) // Start at center (25,25)
        }
        
        // Animate
        withAnimation(.easeOut(duration: 0.6)) {
            for i in 0..<particles.count {
                let radians = particles[i].angle * .pi / 180
                particles[i].x += CGFloat(cos(radians) * particles[i].speed)
                particles[i].y += CGFloat(sin(radians) * particles[i].speed)
                particles[i].opacity = 0
            }
        }
        
        // Clean up
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            particles.removeAll()
        }
    }
}
