//
//  RealTimeTrackingService.swift
//  ToricGuide
//
//  Serviço de rastreamento em tempo real durante a cirurgia
//  Combina detecção de landmarks, matching e correção de ciclotorção
//

import Foundation
import AVFoundation
import UIKit
import Combine

class RealTimeTrackingService: NSObject, ObservableObject {

    // MARK: - Published Properties

    /// Ciclotorção detectada em graus (positivo = horário, negativo = anti-horário)
    @Published var detectedCyclotorsion: Double = 0

    /// Eixo corrigido considerando ciclotorção
    @Published var correctedAxis: Double = 0

    /// Confiança do tracking (0-1)
    @Published var trackingConfidence: Double = 0

    /// Status do tracking
    @Published var trackingStatus: TrackingStatus = .notStarted

    /// Número de vasos matched
    @Published var matchedVessels: Int = 0

    /// Desvio atual do eixo alvo
    @Published var axisDeviation: Double = 0

    /// Está alinhado (dentro de 5°)
    @Published var isAligned: Bool = false

    // MARK: - Configuration

    struct Config {
        static let acceptableDeviation: Double = 5.0 // graus
        static let processingInterval: TimeInterval = 0.1 // 10 FPS para tracking
        static let smoothingFactor: Double = 0.3 // Suavização da ciclotorção
    }

    // MARK: - Private Properties

    private let eyeDetectionService = EyeDetectionService()
    private let matchingService = LandmarkMatchingService()

    private var referenceLandmarks: EyeLandmarks?
    private var referenceImage: UIImage?
    private var targetAxis: Double = 0
    private var eye: Eye = .right

    private var isProcessing = false
    private var lastProcessingTime: Date = Date()

    private var smoothedCyclotorsion: Double = 0
    private var cyclotorsionHistory: [Double] = []
    private let historySize = 5

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    override init() {
        super.init()
        setupObservers()
    }

    private func setupObservers() {
        // Observar mudanças no matching service
        matchingService.$detectedCyclotorsion
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cyclotorsion in
                self?.updateCyclotorsion(cyclotorsion)
            }
            .store(in: &cancellables)

        matchingService.$matchingConfidence
            .receive(on: DispatchQueue.main)
            .sink { [weak self] confidence in
                self?.trackingConfidence = confidence
            }
            .store(in: &cancellables)

        matchingService.$matchedVesselCount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                self?.matchedVessels = count
            }
            .store(in: &cancellables)
    }

    // MARK: - Setup Reference

    /// Configura a referência para tracking
    func setupReference(
        landmarks: EyeLandmarks,
        image: UIImage?,
        targetAxis: Double,
        eye: Eye
    ) {
        self.referenceLandmarks = landmarks
        self.referenceImage = image
        self.targetAxis = targetAxis
        self.eye = eye

        matchingService.setReference(landmarks: landmarks, image: image)

        trackingStatus = .ready
        print("[RealTimeTrackingService] Reference configured. Target axis: \(targetAxis)°")
    }

    // MARK: - Start/Stop Tracking

    func startTracking() {
        guard referenceLandmarks != nil else {
            print("[RealTimeTrackingService] Cannot start: no reference set")
            trackingStatus = .error("Referência não configurada")
            return
        }

        trackingStatus = .tracking
        print("[RealTimeTrackingService] Tracking started")
    }

    func stopTracking() {
        trackingStatus = .stopped
        print("[RealTimeTrackingService] Tracking stopped")
    }

    // MARK: - Process Frame

    /// Processa um frame da câmera para tracking
    /// Deve ser chamado do delegate da câmera
    func processFrame(_ sampleBuffer: CMSampleBuffer) {
        guard trackingStatus == .tracking else { return }
        guard !isProcessing else { return }

        // Controle de taxa de processamento
        let now = Date()
        guard now.timeIntervalSince(lastProcessingTime) >= Config.processingInterval else { return }

        isProcessing = true
        lastProcessingTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            isProcessing = false
            return
        }

        // Processar em background
        Task {
            await processPixelBuffer(pixelBuffer)
            await MainActor.run {
                self.isProcessing = false
            }
        }
    }

    private func processPixelBuffer(_ pixelBuffer: CVPixelBuffer) async {
        // Converter para UIImage
        guard let image = imageFromPixelBuffer(pixelBuffer) else { return }

        // Detectar landmarks na imagem atual
        guard let detectionResult = await eyeDetectionService.processImage(image) else {
            await MainActor.run {
                self.trackingStatus = .searching
            }
            return
        }

        // Verificar se temos detecção válida
        guard detectionResult.quality != .poor else {
            await MainActor.run {
                self.trackingStatus = .searching
            }
            return
        }

        // Fazer matching com referência
        let matchResult = matchingService.matchCurrentFrame(detectionResult: detectionResult)

        await MainActor.run {
            if matchResult.matched {
                self.trackingStatus = .tracking
            } else {
                self.trackingStatus = .searching
            }
        }
    }

    // MARK: - Update Cyclotorsion

    private func updateCyclotorsion(_ newValue: Double) {
        // Adicionar ao histórico
        cyclotorsionHistory.append(newValue)
        if cyclotorsionHistory.count > historySize {
            cyclotorsionHistory.removeFirst()
        }

        // Calcular média ponderada (valores mais recentes têm mais peso)
        var weightedSum: Double = 0
        var weightSum: Double = 0
        for (index, value) in cyclotorsionHistory.enumerated() {
            let weight = Double(index + 1)
            weightedSum += value * weight
            weightSum += weight
        }

        let avgCyclotorsion = weightedSum / weightSum

        // Aplicar suavização exponencial
        smoothedCyclotorsion = smoothedCyclotorsion * (1 - Config.smoothingFactor) +
                               avgCyclotorsion * Config.smoothingFactor

        // Atualizar published values
        detectedCyclotorsion = smoothedCyclotorsion

        // Calcular eixo corrigido
        // Para OD: ciclotorção positiva = rotação horária = eixo aparece menor
        // Para OE: oposto
        let cyclotorsionCorrection = eye == .right ? -smoothedCyclotorsion : smoothedCyclotorsion
        correctedAxis = normalizeAxis(targetAxis + cyclotorsionCorrection)

        // Calcular desvio (para exibição no overlay)
        axisDeviation = abs(smoothedCyclotorsion)
        isAligned = axisDeviation < Config.acceptableDeviation
    }

    // MARK: - Helpers

    private func normalizeAxis(_ axis: Double) -> Double {
        var normalized = axis.truncatingRemainder(dividingBy: 180)
        if normalized < 0 { normalized += 180 }
        return normalized
    }

    private func imageFromPixelBuffer(_ pixelBuffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    // MARK: - Reset

    func reset() {
        stopTracking()
        referenceLandmarks = nil
        referenceImage = nil
        targetAxis = 0
        smoothedCyclotorsion = 0
        cyclotorsionHistory.removeAll()
        matchingService.reset()

        detectedCyclotorsion = 0
        correctedAxis = 0
        trackingConfidence = 0
        matchedVessels = 0
        axisDeviation = 0
        isAligned = false
        trackingStatus = .notStarted
    }

    // MARK: - Manual Cyclotorsion Input

    /// Permite input manual de ciclotorção (quando tracking automático não é confiável)
    func setManualCyclotorsion(_ value: Double) {
        smoothedCyclotorsion = value
        updateCyclotorsion(value)
    }

    /// Ajuste fino da ciclotorção
    func adjustCyclotorsion(by delta: Double) {
        let newValue = smoothedCyclotorsion + delta
        setManualCyclotorsion(newValue)
    }
}

// MARK: - Tracking Status

enum TrackingStatus: Equatable {
    case notStarted
    case ready
    case tracking
    case searching
    case stopped
    case error(String)

    var description: String {
        switch self {
        case .notStarted: return "Não iniciado"
        case .ready: return "Pronto"
        case .tracking: return "Rastreando"
        case .searching: return "Buscando..."
        case .stopped: return "Parado"
        case .error(let msg): return "Erro: \(msg)"
        }
    }

    var color: String {
        switch self {
        case .tracking: return "green"
        case .searching: return "orange"
        case .error: return "red"
        default: return "gray"
        }
    }

    var icon: String {
        switch self {
        case .notStarted: return "circle"
        case .ready: return "checkmark.circle"
        case .tracking: return "eye.fill"
        case .searching: return "magnifyingglass"
        case .stopped: return "stop.circle"
        case .error: return "exclamationmark.triangle"
        }
    }
}

// MARK: - Simulated Tracking (for Testing)

extension RealTimeTrackingService {

    /// Simula tracking para testes sem câmera real
    func startSimulatedTracking(baseAxis: Double) {
        targetAxis = baseAxis
        trackingStatus = .tracking

        // Simular ciclotorção variando levemente
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self, self.trackingStatus == .tracking else {
                timer.invalidate()
                return
            }

            // Ciclotorção simulada: varia entre -5° e +5° com ruído
            let baseCyclotorsion = 2.5 * sin(Date().timeIntervalSince1970 * 0.5)
            let noise = Double.random(in: -0.5...0.5)
            let simulatedCyclotorsion = baseCyclotorsion + noise

            self.updateCyclotorsion(simulatedCyclotorsion)
            self.trackingConfidence = Double.random(in: 0.7...0.95)
            self.matchedVessels = Int.random(in: 4...8)
        }
    }
}
