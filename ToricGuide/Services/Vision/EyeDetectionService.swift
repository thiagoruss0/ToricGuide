//
//  EyeDetectionService.swift
//  ToricGuide
//
//  Serviço de detecção e rastreamento do olho usando Vision Framework
//  Detecta limbo, pupila e vasos limbares para matching
//  Integrado com LimbalVesselDetector para detecção real de vasos
//

import Vision
import UIKit
import CoreImage

class EyeDetectionService: ObservableObject {

    // MARK: - Published Properties
    @Published var limbusDetected = false
    @Published var limbusCenter: CGPoint = .zero
    @Published var limbusRadius: CGFloat = 0

    @Published var pupilDetected = false
    @Published var pupilCenter: CGPoint = .zero
    @Published var pupilRadius: CGFloat = 0

    @Published var detectedVessels: [DetectedVessel] = []
    @Published var processingTime: TimeInterval = 0

    @Published var useRealDetection = true
    @Published var detectionConfidence: Double = 0

    // MARK: - Private Properties
    private let ciContext = CIContext()
    private let vesselDetector = LimbalVesselDetector()
    private let calibrationService = MicroscopeCalibrationService.shared

    // MARK: - Detecção Principal

    /// Processa uma imagem para detectar estruturas oculares
    func processImage(_ image: UIImage) async -> EyeDetectionResult? {
        let startTime = Date()

        // Aplicar calibração se disponível
        let calibratedImage = calibrationService.isCalibrated ?
            calibrationService.transformImage(image) ?? image : image

        guard let cgImage = calibratedImage.cgImage else { return nil }

        // Escolher método de detecção
        if useRealDetection {
            return await processImageWithRealDetection(calibratedImage, startTime: startTime)
        } else {
            return await processImageWithSimulatedDetection(calibratedImage, cgImage: cgImage, startTime: startTime)
        }
    }

    /// Processa imagem usando detecção real de vasos com Vision Framework
    private func processImageWithRealDetection(_ image: UIImage, startTime: Date) async -> EyeDetectionResult? {
        return await withCheckedContinuation { continuation in
            vesselDetector.detectVessels(in: image) { [weak self] result in
                guard let self = self, let result = result else {
                    continuation.resume(returning: nil)
                    return
                }

                let processingTime = Date().timeIntervalSince(startTime)

                // Converter vasos detectados para formato interno
                let vessels = result.vessels.map { vessel in
                    DetectedVessel(
                        id: vessel.id,
                        position: CGPoint(
                            x: vessel.midpoint.x * image.size.width,
                            y: vessel.midpoint.y * image.size.height
                        ),
                        angle: vessel.angle,
                        length: vessel.length * min(image.size.width, image.size.height),
                        confidence: vessel.confidence
                    )
                }

                // Criar resultados de limbo e pupila
                let limbusResult = CircleDetectionResult(
                    center: CGPoint(
                        x: result.limbusCenter.x * image.size.width,
                        y: result.limbusCenter.y * image.size.height
                    ),
                    radius: result.limbusRadius * min(image.size.width, image.size.height),
                    confidence: result.vessels.isEmpty ? 0.5 : 0.8
                )

                // Estimar pupila como fração do limbo
                let pupilResult = CircleDetectionResult(
                    center: limbusResult.center,
                    radius: limbusResult.radius * 0.35,
                    confidence: 0.7
                )

                DispatchQueue.main.async {
                    self.limbusDetected = true
                    self.limbusCenter = limbusResult.center
                    self.limbusRadius = limbusResult.radius

                    self.pupilDetected = true
                    self.pupilCenter = pupilResult.center
                    self.pupilRadius = pupilResult.radius

                    self.detectedVessels = vessels
                    self.processingTime = processingTime
                    self.detectionConfidence = vessels.reduce(0) { $0 + $1.confidence } /
                        max(Double(vessels.count), 1)
                }

                let eyeResult = EyeDetectionResult(
                    limbus: limbusResult,
                    pupil: pupilResult,
                    vessels: vessels,
                    quality: self.calculateQuality(limbusResult, pupilResult, vessels)
                )

                continuation.resume(returning: eyeResult)
            }
        }
    }

    /// Processa imagem usando detecção simulada (fallback)
    private func processImageWithSimulatedDetection(
        _ image: UIImage,
        cgImage: CGImage,
        startTime: Date
    ) async -> EyeDetectionResult? {
        // 1. Detectar face e olhos usando Vision
        let faceRequest = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([faceRequest])
        } catch {
            print("Erro na detecção facial: \(error)")
        }

        // 2. Obter região do olho (se detectou face)
        let eyeRegion: UIImage?
        if let faceObservation = faceRequest.results?.first {
            eyeRegion = extractEyeRegion(from: faceObservation, image: image)
        } else {
            eyeRegion = nil
        }

        // 3. Detectar limbo usando Hough Circle Transform (via Core Image)
        let limbusResult = detectLimbus(in: eyeRegion ?? image)

        // 4. Detectar pupila
        let pupilResult = detectPupil(in: eyeRegion ?? image)

        // 5. Detectar vasos limbares (simulado)
        let vessels = detectLimbalVessels(in: eyeRegion ?? image)

        let processingTime = Date().timeIntervalSince(startTime)

        DispatchQueue.main.async {
            self.limbusDetected = limbusResult != nil
            if let limbus = limbusResult {
                self.limbusCenter = limbus.center
                self.limbusRadius = limbus.radius
            }

            self.pupilDetected = pupilResult != nil
            if let pupil = pupilResult {
                self.pupilCenter = pupil.center
                self.pupilRadius = pupil.radius
            }

            self.detectedVessels = vessels
            self.processingTime = processingTime
        }

        return EyeDetectionResult(
            limbus: limbusResult,
            pupil: pupilResult,
            vessels: vessels,
            quality: calculateQuality(limbusResult, pupilResult, vessels)
        )
    }

    /// Processa um pixel buffer (para câmera em tempo real)
    func processPixelBuffer(_ pixelBuffer: CVPixelBuffer) async -> EyeDetectionResult? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        let uiImage = UIImage(cgImage: cgImage)
        return await processImage(uiImage)
    }

    /// Converte resultado de detecção para EyeLandmarks
    func convertToLandmarks(from result: EyeDetectionResult) -> EyeLandmarks? {
        guard let limbus = result.limbus else { return nil }

        let vesselDescriptors = result.vessels.map { vessel in
            VesselDescriptor(
                angle: vessel.angle,
                normalizedPosition: CGPoint(
                    x: vessel.position.x / (limbus.center.x * 2),
                    y: vessel.position.y / (limbus.center.y * 2)
                ),
                length: vessel.length / limbus.radius,
                thickness: 0.02
            )
        }

        return EyeLandmarks(
            pupilCenter: result.pupil?.center ?? limbus.center,
            limbusRadius: limbus.radius,
            limbalVessels: vesselDescriptors,
            irisFeatures: [],
            timestamp: Date()
        )
    }

    // MARK: - Detecção de Limbo

    private func detectLimbus(in image: UIImage) -> CircleDetectionResult? {
        guard let ciImage = CIImage(image: image) else { return nil }

        // Aplicar filtros para realçar o limbo
        // 1. Converter para escala de cinza
        let grayscale = ciImage.applyingFilter("CIColorControls", parameters: [
            "inputSaturation": 0
        ])

        // 2. Aplicar edge detection
        let edges = grayscale.applyingFilter("CIEdges", parameters: [
            "inputIntensity": 1.0
        ])

        // 3. Usar Hough Transform para detectar círculos
        // Nota: iOS não tem Hough Transform nativo, então usamos uma aproximação
        // baseada em contornos

        // Por enquanto, retornar uma estimativa baseada no tamanho da imagem
        let center = CGPoint(x: image.size.width / 2, y: image.size.height / 2)
        let estimatedRadius = min(image.size.width, image.size.height) * 0.4

        return CircleDetectionResult(
            center: center,
            radius: estimatedRadius,
            confidence: 0.8
        )
    }

    // MARK: - Detecção de Pupila

    private func detectPupil(in image: UIImage) -> CircleDetectionResult? {
        guard let ciImage = CIImage(image: image) else { return nil }

        // A pupila é escura, então vamos threshold para detectar
        let thresholded = ciImage.applyingFilter("CIColorThreshold", parameters: [
            "inputThreshold": 0.3
        ])

        // Encontrar o blob escuro central
        // Simplificação: assumir que está no centro
        let center = CGPoint(x: image.size.width / 2, y: image.size.height / 2)
        let estimatedRadius = min(image.size.width, image.size.height) * 0.15

        return CircleDetectionResult(
            center: center,
            radius: estimatedRadius,
            confidence: 0.75
        )
    }

    // MARK: - Detecção de Vasos Limbares

    private func detectLimbalVessels(in image: UIImage) -> [DetectedVessel] {
        guard let ciImage = CIImage(image: image) else { return [] }

        // Realçar vermelho (vasos são avermelhados)
        let enhanced = ciImage.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 2, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 0.5, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 0.5, w: 0)
        ])

        // Em produção, usaríamos um modelo de ML treinado para detectar vasos
        // Por enquanto, gerar alguns vasos de exemplo
        var vessels: [DetectedVessel] = []
        let center = CGPoint(x: image.size.width / 2, y: image.size.height / 2)
        let radius = min(image.size.width, image.size.height) * 0.4

        // Gerar 8-12 vasos em posições típicas
        for i in 0..<Int.random(in: 8...12) {
            let angle = Double(i) * 30 + Double.random(in: -10...10)
            let radians = angle * .pi / 180

            let x = center.x + radius * CGFloat(cos(radians))
            let y = center.y + radius * CGFloat(sin(radians))

            vessels.append(DetectedVessel(
                id: UUID(),
                position: CGPoint(x: x, y: y),
                angle: angle,
                length: CGFloat.random(in: 10...30),
                confidence: Double.random(in: 0.6...0.95)
            ))
        }

        return vessels
    }

    // MARK: - Extração de Região do Olho

    private func extractEyeRegion(from face: VNFaceObservation, image: UIImage) -> UIImage? {
        guard let landmarks = face.landmarks,
              let leftEye = landmarks.leftEye else {
            return nil
        }

        // Obter bounding box do olho
        let eyePoints = leftEye.normalizedPoints

        // Calcular bounding box
        var minX: CGFloat = 1, maxX: CGFloat = 0
        var minY: CGFloat = 1, maxY: CGFloat = 0

        for point in eyePoints {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }

        // Expandir a região
        let padding: CGFloat = 0.1
        minX = max(0, minX - padding)
        maxX = min(1, maxX + padding)
        minY = max(0, minY - padding)
        maxY = min(1, maxY + padding)

        // Converter para coordenadas da imagem
        let cropRect = CGRect(
            x: minX * image.size.width,
            y: (1 - maxY) * image.size.height, // Inverter Y
            width: (maxX - minX) * image.size.width,
            height: (maxY - minY) * image.size.height
        )

        guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    // MARK: - Qualidade da Detecção

    private func calculateQuality(
        _ limbus: CircleDetectionResult?,
        _ pupil: CircleDetectionResult?,
        _ vessels: [DetectedVessel]
    ) -> CaptureQuality {
        var score = 0.0

        if let limbus = limbus {
            score += limbus.confidence * 0.3
        }

        if let pupil = pupil {
            score += pupil.confidence * 0.3
        }

        let avgVesselConfidence = vessels.isEmpty ? 0 :
            vessels.reduce(0) { $0 + $1.confidence } / Double(vessels.count)
        score += avgVesselConfidence * 0.4

        switch score {
        case 0.8...: return .excellent
        case 0.6..<0.8: return .good
        case 0.4..<0.6: return .acceptable
        default: return .poor
        }
    }
}

// MARK: - Comparação de Imagens (Ciclotorção)

extension EyeDetectionService {

    /// Compara imagem de referência com imagem atual para detectar ciclotorção
    func detectCyclotorsion(
        reference: EyeDetectionResult,
        current: EyeDetectionResult
    ) -> Double {

        // Comparar posição angular dos vasos
        guard !reference.vessels.isEmpty, !current.vessels.isEmpty else {
            return 0
        }

        // Encontrar correspondência entre vasos
        var totalRotation = 0.0
        var matchCount = 0

        for refVessel in reference.vessels {
            // Encontrar vaso correspondente na imagem atual
            if let matchedVessel = findMatchingVessel(refVessel, in: current.vessels) {
                let rotation = matchedVessel.angle - refVessel.angle
                totalRotation += rotation
                matchCount += 1
            }
        }

        guard matchCount > 0 else { return 0 }

        return totalRotation / Double(matchCount)
    }

    private func findMatchingVessel(
        _ reference: DetectedVessel,
        in candidates: [DetectedVessel]
    ) -> DetectedVessel? {
        // Encontrar vaso com posição angular mais próxima
        // permitindo uma margem de ±30°
        let margin = 30.0

        return candidates.min { v1, v2 in
            let diff1 = abs(angleDifference(v1.angle, reference.angle))
            let diff2 = abs(angleDifference(v2.angle, reference.angle))
            return diff1 < diff2
        }.flatMap { vessel in
            abs(angleDifference(vessel.angle, reference.angle)) < margin ? vessel : nil
        }
    }

    private func angleDifference(_ a1: Double, _ a2: Double) -> Double {
        var diff = a1 - a2
        while diff > 180 { diff -= 360 }
        while diff < -180 { diff += 360 }
        return diff
    }
}

// MARK: - Estruturas de Suporte

struct CircleDetectionResult {
    let center: CGPoint
    let radius: CGFloat
    let confidence: Double
}

struct DetectedVessel: Identifiable {
    let id: UUID
    let position: CGPoint
    let angle: Double
    let length: CGFloat
    let confidence: Double
}

struct EyeDetectionResult {
    let limbus: CircleDetectionResult?
    let pupil: CircleDetectionResult?
    let vessels: [DetectedVessel]
    let quality: CaptureQuality
}
