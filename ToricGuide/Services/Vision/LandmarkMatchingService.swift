//
//  LandmarkMatchingService.swift
//  ToricGuide
//
//  Serviço de matching de landmarks entre imagem de referência e imagem atual
//  Detecta ciclotorção comparando padrões de vasos limbares
//

import Foundation
import UIKit
import CoreImage
import Accelerate

class LandmarkMatchingService: ObservableObject {

    // MARK: - Published Properties
    @Published var matchingConfidence: Double = 0
    @Published var detectedCyclotorsion: Double = 0
    @Published var isMatched = false
    @Published var matchedVesselCount = 0

    // Landmarks de referência
    private var referenceLandmarks: EyeLandmarks?
    private var referenceDescriptors: [VesselDescriptor] = []

    // Configuração
    struct Config {
        static let minMatchedVessels = 3
        static let maxAngleDifference: Double = 45 // graus
        static let minMatchConfidence: Double = 0.6
        static let vesselMatchThreshold: Double = 0.7
    }

    // MARK: - Set Reference

    /// Define a imagem de referência para comparação
    func setReference(landmarks: EyeLandmarks, image: UIImage?) {
        self.referenceLandmarks = landmarks

        // Criar descritores dos vasos de referência
        self.referenceDescriptors = landmarks.limbalVessels.map { vessel in
            VesselDescriptor(
                id: vessel.id,
                angle: vessel.angle,
                normalizedPosition: normalizePosition(vessel.position.cgPoint, relativeTo: landmarks.limbusCenter.cgPoint),
                length: vessel.length,
                thickness: vessel.thickness
            )
        }

        print("[LandmarkMatchingService] Reference set with \(referenceDescriptors.count) vessels")
    }

    // MARK: - Match Current Frame

    /// Compara a detecção atual com a referência
    /// - Returns: Ciclotorção detectada em graus
    func matchCurrentFrame(detectionResult: EyeDetectionResult) -> MatchingResult {
        guard let refLandmarks = referenceLandmarks else {
            return MatchingResult(cyclotorsion: 0, confidence: 0, matched: false, matchedVessels: 0)
        }

        // Criar descritores dos vasos atuais
        let currentDescriptors = detectionResult.vessels.map { vessel in
            VesselDescriptor(
                id: vessel.id,
                angle: vessel.angle,
                normalizedPosition: normalizePosition(
                    vessel.position,
                    relativeTo: detectionResult.limbus?.center ?? .zero
                ),
                length: vessel.length,
                thickness: 0 // Não disponível em DetectedVessel
            )
        }

        // Encontrar correspondências
        let matches = findMatches(reference: referenceDescriptors, current: currentDescriptors)

        // Calcular ciclotorção
        let cyclotorsion = calculateCyclotorsion(matches: matches)

        // Calcular confiança
        let confidence = calculateMatchConfidence(matches: matches, totalReference: referenceDescriptors.count)

        let isMatched = matches.count >= Config.minMatchedVessels && confidence >= Config.minMatchConfidence

        // Atualizar published properties
        DispatchQueue.main.async {
            self.detectedCyclotorsion = cyclotorsion
            self.matchingConfidence = confidence
            self.isMatched = isMatched
            self.matchedVesselCount = matches.count
        }

        return MatchingResult(
            cyclotorsion: cyclotorsion,
            confidence: confidence,
            matched: isMatched,
            matchedVessels: matches.count
        )
    }

    // MARK: - Find Matches

    private func findMatches(
        reference: [VesselDescriptor],
        current: [VesselDescriptor]
    ) -> [VesselMatch] {
        var matches: [VesselMatch] = []
        var usedCurrentIndices = Set<Int>()

        for refVessel in reference {
            var bestMatch: VesselMatch?
            var bestScore: Double = 0

            for (index, curVessel) in current.enumerated() {
                guard !usedCurrentIndices.contains(index) else { continue }

                let score = calculateMatchScore(ref: refVessel, cur: curVessel)

                if score > bestScore && score >= Config.vesselMatchThreshold {
                    bestScore = score
                    bestMatch = VesselMatch(
                        referenceVessel: refVessel,
                        currentVessel: curVessel,
                        score: score,
                        angleDifference: angleDifference(refVessel.angle, curVessel.angle)
                    )
                }
            }

            if let match = bestMatch {
                matches.append(match)
                if let idx = current.firstIndex(where: { $0.id == match.currentVessel.id }) {
                    usedCurrentIndices.insert(idx)
                }
            }
        }

        return matches
    }

    // MARK: - Calculate Match Score

    private func calculateMatchScore(ref: VesselDescriptor, cur: VesselDescriptor) -> Double {
        // Score baseado em múltiplos fatores

        // 1. Similaridade de posição radial (distância do centro)
        let refRadius = sqrt(pow(ref.normalizedPosition.x, 2) + pow(ref.normalizedPosition.y, 2))
        let curRadius = sqrt(pow(cur.normalizedPosition.x, 2) + pow(cur.normalizedPosition.y, 2))
        let radiusDiff = abs(refRadius - curRadius)
        let radiusScore = max(0, 1 - radiusDiff * 5) // Penalidade de 0.2 por 0.04 de diferença

        // 2. Similaridade de comprimento
        let lengthRatio = min(ref.length, cur.length) / max(ref.length, cur.length)
        let lengthScore = lengthRatio

        // 3. Diferença angular (considerando que pode haver rotação)
        // Usamos a posição angular relativa, não absoluta
        let angleDiff = abs(angleDifference(ref.angle, cur.angle))
        let angleScore: Double
        if angleDiff <= Config.maxAngleDifference {
            angleScore = 1 - (angleDiff / Config.maxAngleDifference)
        } else {
            angleScore = 0
        }

        // Pesos: posição é mais importante, seguido de ângulo, depois comprimento
        let totalScore = radiusScore * 0.4 + angleScore * 0.4 + lengthScore * 0.2

        return totalScore
    }

    // MARK: - Calculate Cyclotorsion

    private func calculateCyclotorsion(matches: [VesselMatch]) -> Double {
        guard !matches.isEmpty else { return 0 }

        // Usar média ponderada das diferenças angulares
        var weightedSum: Double = 0
        var weightSum: Double = 0

        for match in matches {
            let weight = match.score
            weightedSum += match.angleDifference * weight
            weightSum += weight
        }

        guard weightSum > 0 else { return 0 }

        return weightedSum / weightSum
    }

    // MARK: - Calculate Match Confidence

    private func calculateMatchConfidence(matches: [VesselMatch], totalReference: Int) -> Double {
        guard totalReference > 0 else { return 0 }

        // Fator 1: Proporção de vasos matched
        let matchRatio = Double(matches.count) / Double(totalReference)

        // Fator 2: Média dos scores de match
        let avgScore = matches.isEmpty ? 0 : matches.reduce(0) { $0 + $1.score } / Double(matches.count)

        // Fator 3: Consistência das diferenças angulares (baixo desvio padrão = bom)
        let angleConsistency = calculateAngleConsistency(matches: matches)

        // Combinar fatores
        let confidence = matchRatio * 0.3 + avgScore * 0.4 + angleConsistency * 0.3

        return min(1, confidence)
    }

    private func calculateAngleConsistency(matches: [VesselMatch]) -> Double {
        guard matches.count >= 2 else { return 1.0 }

        let angles = matches.map { $0.angleDifference }
        let mean = angles.reduce(0, +) / Double(angles.count)
        let variance = angles.reduce(0) { $0 + pow($1 - mean, 2) } / Double(angles.count)
        let stdDev = sqrt(variance)

        // Menor desvio padrão = maior consistência
        // Esperamos stdDev < 5° para boa consistência
        return max(0, 1 - (stdDev / 10))
    }

    // MARK: - Helpers

    private func normalizePosition(_ position: CGPoint, relativeTo center: CGPoint) -> CGPoint {
        // Normalizar posição relativa ao centro do limbo
        return CGPoint(
            x: position.x - center.x,
            y: position.y - center.y
        )
    }

    private func angleDifference(_ a1: Double, _ a2: Double) -> Double {
        var diff = a1 - a2
        while diff > 180 { diff -= 360 }
        while diff < -180 { diff += 360 }
        return diff
    }

    // MARK: - Reset

    func reset() {
        referenceLandmarks = nil
        referenceDescriptors = []

        DispatchQueue.main.async {
            self.matchingConfidence = 0
            self.detectedCyclotorsion = 0
            self.isMatched = false
            self.matchedVesselCount = 0
        }
    }
}

// MARK: - Supporting Types

struct VesselDescriptor: Identifiable {
    let id: UUID
    let angle: Double
    let normalizedPosition: CGPoint
    let length: CGFloat
    let thickness: CGFloat
}

struct VesselMatch {
    let referenceVessel: VesselDescriptor
    let currentVessel: VesselDescriptor
    let score: Double
    let angleDifference: Double
}

struct MatchingResult {
    let cyclotorsion: Double
    let confidence: Double
    let matched: Bool
    let matchedVessels: Int

    var qualityDescription: String {
        switch confidence {
        case 0.8...: return "Excelente"
        case 0.6..<0.8: return "Bom"
        case 0.4..<0.6: return "Aceitável"
        default: return "Baixo"
        }
    }
}

// MARK: - Real-time Tracking Extension

extension LandmarkMatchingService {

    /// Processa frame em tempo real para tracking
    func processFrame(_ pixelBuffer: CVPixelBuffer, eyeDetectionService: EyeDetectionService) async -> MatchingResult? {
        // Converter pixel buffer para UIImage
        guard let image = imageFromPixelBuffer(pixelBuffer) else { return nil }

        // Detectar landmarks na imagem atual
        guard let detectionResult = await eyeDetectionService.processImage(image) else { return nil }

        // Fazer matching com referência
        return matchCurrentFrame(detectionResult: detectionResult)
    }

    private func imageFromPixelBuffer(_ pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}
