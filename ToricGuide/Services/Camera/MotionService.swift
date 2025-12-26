//
//  MotionService.swift
//  ToricGuide
//
//  Serviço de giroscópio para nivelar o dispositivo
//

import CoreMotion
import SwiftUI

class MotionService: ObservableObject {
    // MARK: - Published Properties
    @Published var roll: Double = 0        // Rotação lateral (em graus)
    @Published var pitch: Double = 0       // Inclinação frente/trás (em graus)
    @Published var isLeveled = false       // Se está nivelado (< 2°)
    @Published var levelingProgress: Double = 0 // 0-1 para indicador visual

    // MARK: - Private Properties
    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()
    private let updateInterval = 1.0 / 60.0 // 60 Hz

    // Threshold para considerar nivelado (em graus)
    private let levelThreshold: Double = 2.0

    // MARK: - Initialization
    init() {
        queue.name = "MotionServiceQueue"
        queue.maxConcurrentOperationCount = 1
    }

    // MARK: - Start/Stop
    func startUpdates() {
        guard motionManager.isDeviceMotionAvailable else {
            print("Device motion not available")
            return
        }

        motionManager.deviceMotionUpdateInterval = updateInterval

        motionManager.startDeviceMotionUpdates(
            using: .xArbitraryZVertical,
            to: queue
        ) { [weak self] motion, error in
            guard let self = self,
                  let motion = motion,
                  error == nil else {
                return
            }

            // Converter radianos para graus
            let rollDegrees = motion.attitude.roll * 180 / .pi
            let pitchDegrees = motion.attitude.pitch * 180 / .pi

            DispatchQueue.main.async {
                self.roll = rollDegrees
                self.pitch = pitchDegrees

                // Verificar se está nivelado (roll próximo de 0)
                let absRoll = abs(rollDegrees)
                self.isLeveled = absRoll < self.levelThreshold

                // Calcular progresso (0 = muito inclinado, 1 = perfeitamente nivelado)
                // Máximo de 45 graus de inclinação considerado
                let maxAngle: Double = 45.0
                self.levelingProgress = max(0, min(1, 1 - (absRoll / maxAngle)))
            }
        }
    }

    func stopUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }

    // MARK: - Current Horizontal Axis
    /// Retorna o eixo horizontal atual do dispositivo em graus (0-360)
    var currentHorizontalAxis: Double {
        // Normalizar o roll para 0-360
        var axis = roll
        if axis < 0 {
            axis += 360
        }
        return axis.truncatingRemainder(dividingBy: 360)
    }
}

// MARK: - Level Indicator View
struct LevelIndicatorView: View {
    @ObservedObject var motionService: MotionService

    var body: some View {
        VStack(spacing: 8) {
            // Indicador visual de nível
            HStack(spacing: 4) {
                ForEach(0..<21) { index in
                    let centerIndex = 10
                    let distanceFromCenter = abs(index - centerIndex)

                    // Calcular se este segmento deve estar ativo
                    let rollNormalized = motionService.roll / 45.0 // -1 a 1 para -45° a 45°
                    let segmentPosition = Double(index - centerIndex) / 10.0 // -1 a 1
                    let isActive = abs(rollNormalized - segmentPosition) < 0.15

                    Rectangle()
                        .fill(segmentColor(index: index, isActive: isActive))
                        .frame(width: index == centerIndex ? 4 : 2, height: index == centerIndex ? 16 : 12)
                }
            }

            // Texto do ângulo
            HStack(spacing: 4) {
                Text("Eixo Horizontal:")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text(String(format: "%.1f°", abs(motionService.roll)))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(motionService.isLeveled ? .green : .orange)

                if motionService.isLeveled {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground).opacity(0.9))
        .cornerRadius(8)
    }

    private func segmentColor(index: Int, isActive: Bool) -> Color {
        let centerIndex = 10

        if isActive {
            if index == centerIndex {
                return motionService.isLeveled ? .green : .orange
            }
            return motionService.isLeveled ? .green.opacity(0.7) : .orange.opacity(0.7)
        }

        return Color(.systemGray4)
    }
}

// MARK: - Bubble Level View
struct BubbleLevelView: View {
    @ObservedObject var motionService: MotionService

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Linha central (alvo)
                Rectangle()
                    .fill(Color.green.opacity(0.3))
                    .frame(width: 4, height: geometry.size.height)

                // Linhas de referência
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1, height: geometry.size.height)
                    .offset(x: -20)

                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 1, height: geometry.size.height)
                    .offset(x: 20)

                // Bolha
                Circle()
                    .fill(motionService.isLeveled ? Color.green : Color.orange)
                    .frame(width: 20, height: 20)
                    .offset(x: bubbleOffset(width: geometry.size.width))
                    .animation(.easeOut(duration: 0.1), value: motionService.roll)
            }
        }
        .frame(height: 40)
        .background(Color(.systemGray6))
        .cornerRadius(20)
    }

    private func bubbleOffset(width: CGFloat) -> CGFloat {
        // Converter roll (-45 a 45 graus) para offset
        let maxOffset = width / 2 - 20
        let normalizedRoll = motionService.roll / 45.0
        return CGFloat(normalizedRoll) * maxOffset
    }
}
