//
//  MicroscopeCalibrationService.swift
//  ToricGuide
//
//  Sistema de calibração para o adaptador MicroRec + Zeiss Opmi Lumera I
//  Gerencia correções de distorção, escala e rotação
//

import Foundation
import UIKit
import CoreImage
import Accelerate

class MicroscopeCalibrationService: ObservableObject {

    // MARK: - Singleton
    static let shared = MicroscopeCalibrationService()

    // MARK: - Published Properties
    @Published var isCalibrated = false
    @Published var calibrationQuality: CalibrationQuality = .unknown
    @Published var lastCalibrationDate: Date?

    // MARK: - Calibration Data
    private(set) var calibrationData: CalibrationData?

    // Storage key
    private let calibrationKey = "toricguide_microscope_calibration"

    // MARK: - Calibration Quality
    enum CalibrationQuality: String, Codable {
        case unknown = "Desconhecido"
        case poor = "Baixa"
        case acceptable = "Aceitável"
        case good = "Boa"
        case excellent = "Excelente"

        var color: String {
            switch self {
            case .unknown: return "gray"
            case .poor: return "red"
            case .acceptable: return "orange"
            case .good: return "green"
            case .excellent: return "blue"
            }
        }
    }

    // MARK: - Calibration Data Structure
    struct CalibrationData: Codable {
        // Optical parameters
        var opticalCenterX: Double      // Center offset X (normalized, -0.5 to 0.5)
        var opticalCenterY: Double      // Center offset Y (normalized, -0.5 to 0.5)
        var rotationOffset: Double      // Rotation offset in degrees
        var scaleFactor: Double         // Scale correction factor

        // Distortion parameters (radial distortion model)
        var k1: Double                  // First radial distortion coefficient
        var k2: Double                  // Second radial distortion coefficient
        var k3: Double                  // Third radial distortion coefficient

        // Tangential distortion
        var p1: Double                  // First tangential distortion coefficient
        var p2: Double                  // Second tangential distortion coefficient

        // Equipment info
        var equipmentName: String
        var microscopeModel: String
        var adapterType: String
        var zoomLevel: Double

        // Metadata
        var calibrationDate: Date
        var quality: CalibrationQuality
        var validationError: Double     // Average error in pixels during validation

        // Default calibration for MicroRec + Zeiss Opmi Lumera I
        static var defaultCalibration: CalibrationData {
            CalibrationData(
                opticalCenterX: 0.0,
                opticalCenterY: 0.0,
                rotationOffset: 0.0,
                scaleFactor: 1.0,
                k1: 0.0,
                k2: 0.0,
                k3: 0.0,
                p1: 0.0,
                p2: 0.0,
                equipmentName: "MicroRec Default",
                microscopeModel: "Zeiss Opmi Lumera I",
                adapterType: "MicroRec (Custom Surgical)",
                zoomLevel: 1.0,
                calibrationDate: Date(),
                quality: .unknown,
                validationError: 0.0
            )
        }
    }

    // MARK: - Calibration Target
    struct CalibrationTarget {
        let knownPoints: [CGPoint]      // Known positions on calibration target
        let measuredPoints: [CGPoint]   // Measured positions in image
        let knownDiameter: Double       // Known diameter in mm
        let measuredDiameter: Double    // Measured diameter in pixels
    }

    // MARK: - Initialization
    private init() {
        loadCalibration()
    }

    // MARK: - Load/Save Calibration

    private func loadCalibration() {
        if let data = UserDefaults.standard.data(forKey: calibrationKey),
           let decoded = try? JSONDecoder().decode(CalibrationData.self, from: data) {
            calibrationData = decoded
            isCalibrated = true
            calibrationQuality = decoded.quality
            lastCalibrationDate = decoded.calibrationDate
        } else {
            calibrationData = CalibrationData.defaultCalibration
            isCalibrated = false
        }
    }

    func saveCalibration() {
        guard let data = calibrationData else { return }

        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: calibrationKey)
            isCalibrated = true
            lastCalibrationDate = data.calibrationDate
            calibrationQuality = data.quality
        }
    }

    func resetCalibration() {
        calibrationData = CalibrationData.defaultCalibration
        isCalibrated = false
        calibrationQuality = .unknown
        lastCalibrationDate = nil
        UserDefaults.standard.removeObject(forKey: calibrationKey)
    }

    // MARK: - Calibration Process

    /// Start calibration with a set of reference points
    func calibrate(
        using target: CalibrationTarget,
        zoomLevel: Double,
        completion: @escaping (Result<CalibrationData, CalibrationError>) -> Void
    ) {
        guard target.knownPoints.count >= 4,
              target.knownPoints.count == target.measuredPoints.count else {
            completion(.failure(.insufficientPoints))
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Step 1: Calculate center offset
            let centerOffset = self.calculateCenterOffset(
                known: target.knownPoints,
                measured: target.measuredPoints
            )

            // Step 2: Calculate rotation
            let rotation = self.calculateRotation(
                known: target.knownPoints,
                measured: target.measuredPoints
            )

            // Step 3: Calculate scale
            let scale = target.measuredDiameter / target.knownDiameter

            // Step 4: Calculate distortion coefficients
            let distortion = self.calculateDistortion(
                known: target.knownPoints,
                measured: target.measuredPoints,
                center: centerOffset
            )

            // Step 5: Validate calibration
            let (quality, error) = self.validateCalibration(
                known: target.knownPoints,
                measured: target.measuredPoints,
                centerOffset: centerOffset,
                rotation: rotation,
                scale: scale,
                distortion: distortion
            )

            // Create calibration data
            var data = CalibrationData(
                opticalCenterX: centerOffset.x,
                opticalCenterY: centerOffset.y,
                rotationOffset: rotation,
                scaleFactor: scale,
                k1: distortion.k1,
                k2: distortion.k2,
                k3: distortion.k3,
                p1: distortion.p1,
                p2: distortion.p2,
                equipmentName: "MicroRec Custom",
                microscopeModel: "Zeiss Opmi Lumera I",
                adapterType: "MicroRec (Custom Surgical)",
                zoomLevel: zoomLevel,
                calibrationDate: Date(),
                quality: quality,
                validationError: error
            )

            DispatchQueue.main.async {
                self.calibrationData = data
                self.saveCalibration()
                completion(.success(data))
            }
        }
    }

    /// Quick calibration using rotation offset only (simplified)
    func quickCalibrate(rotationOffset: Double, zoomLevel: Double) {
        var data = calibrationData ?? CalibrationData.defaultCalibration
        data.rotationOffset = rotationOffset
        data.zoomLevel = zoomLevel
        data.calibrationDate = Date()
        data.quality = .acceptable

        calibrationData = data
        saveCalibration()
    }

    // MARK: - Point Transformation

    /// Apply calibration to transform a point
    func transformPoint(_ point: CGPoint, imageSize: CGSize) -> CGPoint {
        guard let data = calibrationData else { return point }

        // Normalize to center
        var x = (point.x / imageSize.width) - 0.5
        var y = (point.y / imageSize.height) - 0.5

        // Apply center offset
        x -= data.opticalCenterX
        y -= data.opticalCenterY

        // Apply radial distortion correction
        let r2 = x * x + y * y
        let r4 = r2 * r2
        let r6 = r4 * r2

        let radialFactor = 1 + data.k1 * r2 + data.k2 * r4 + data.k3 * r6

        let xDistorted = x * radialFactor + 2 * data.p1 * x * y + data.p2 * (r2 + 2 * x * x)
        let yDistorted = y * radialFactor + data.p1 * (r2 + 2 * y * y) + 2 * data.p2 * x * y

        // Apply rotation
        let rotRad = data.rotationOffset * .pi / 180.0
        let xRotated = xDistorted * cos(rotRad) - yDistorted * sin(rotRad)
        let yRotated = xDistorted * sin(rotRad) + yDistorted * cos(rotRad)

        // Apply scale and convert back
        let xFinal = (xRotated * data.scaleFactor + 0.5) * imageSize.width
        let yFinal = (yRotated * data.scaleFactor + 0.5) * imageSize.height

        return CGPoint(x: xFinal, y: yFinal)
    }

    /// Apply calibration to transform an angle
    func transformAngle(_ angle: Double) -> Double {
        guard let data = calibrationData else { return angle }

        var correctedAngle = angle - data.rotationOffset

        // Normalize to 0-180 range
        while correctedAngle < 0 { correctedAngle += 180 }
        while correctedAngle >= 180 { correctedAngle -= 180 }

        return correctedAngle
    }

    /// Inverse transform (from calibrated to raw)
    func inverseTransformPoint(_ point: CGPoint, imageSize: CGSize) -> CGPoint {
        guard let data = calibrationData else { return point }

        // Normalize and remove scale
        var x = ((point.x / imageSize.width) - 0.5) / data.scaleFactor
        var y = ((point.y / imageSize.height) - 0.5) / data.scaleFactor

        // Remove rotation
        let rotRad = -data.rotationOffset * .pi / 180.0
        let xUnrotated = x * cos(rotRad) - y * sin(rotRad)
        let yUnrotated = x * sin(rotRad) + y * cos(rotRad)

        // Note: Distortion inversion is complex, using approximation
        // For small distortions, we can use negative coefficients
        let r2 = xUnrotated * xUnrotated + yUnrotated * yUnrotated

        let xUndistorted = xUnrotated / (1 + data.k1 * r2)
        let yUndistorted = yUnrotated / (1 + data.k1 * r2)

        // Add center offset back
        let xFinal = (xUndistorted + data.opticalCenterX + 0.5) * imageSize.width
        let yFinal = (yUndistorted + data.opticalCenterY + 0.5) * imageSize.height

        return CGPoint(x: xFinal, y: yFinal)
    }

    // MARK: - Image Transformation

    /// Apply calibration to entire image
    func transformImage(_ image: UIImage) -> UIImage? {
        guard let data = calibrationData,
              let cgImage = image.cgImage else { return image }

        let ciImage = CIImage(cgImage: cgImage)

        // Apply perspective/affine transform based on calibration
        var transform = CGAffineTransform.identity

        // Center
        let centerX = ciImage.extent.width / 2
        let centerY = ciImage.extent.height / 2

        // Move to origin
        transform = transform.translatedBy(x: -centerX, y: -centerY)

        // Apply rotation
        transform = transform.rotated(by: CGFloat(data.rotationOffset * .pi / 180.0))

        // Apply scale
        transform = transform.scaledBy(x: CGFloat(data.scaleFactor), y: CGFloat(data.scaleFactor))

        // Move back
        transform = transform.translatedBy(x: centerX, y: centerY)

        // Apply center offset
        transform = transform.translatedBy(
            x: CGFloat(data.opticalCenterX) * ciImage.extent.width,
            y: CGFloat(data.opticalCenterY) * ciImage.extent.height
        )

        let transformedImage = ciImage.transformed(by: transform)

        let context = CIContext()
        guard let outputCGImage = context.createCGImage(transformedImage, from: transformedImage.extent) else {
            return image
        }

        return UIImage(cgImage: outputCGImage)
    }

    // MARK: - Private Calculation Methods

    private func calculateCenterOffset(known: [CGPoint], measured: [CGPoint]) -> CGPoint {
        // Calculate centroid difference
        let knownCentroid = centroid(of: known)
        let measuredCentroid = centroid(of: measured)

        return CGPoint(
            x: measuredCentroid.x - knownCentroid.x,
            y: measuredCentroid.y - knownCentroid.y
        )
    }

    private func calculateRotation(known: [CGPoint], measured: [CGPoint]) -> Double {
        // Use Procrustes analysis to find optimal rotation
        let knownCentroid = centroid(of: known)
        let measuredCentroid = centroid(of: measured)

        var sumSin: Double = 0
        var sumCos: Double = 0

        for i in 0..<known.count {
            let kx = known[i].x - knownCentroid.x
            let ky = known[i].y - knownCentroid.y
            let mx = measured[i].x - measuredCentroid.x
            let my = measured[i].y - measuredCentroid.y

            // Cross product gives sin(angle), dot product gives cos(angle)
            sumSin += kx * my - ky * mx
            sumCos += kx * mx + ky * my
        }

        let angle = atan2(sumSin, sumCos) * 180.0 / .pi
        return angle
    }

    private struct DistortionCoefficients {
        var k1: Double = 0
        var k2: Double = 0
        var k3: Double = 0
        var p1: Double = 0
        var p2: Double = 0
    }

    private func calculateDistortion(
        known: [CGPoint],
        measured: [CGPoint],
        center: CGPoint
    ) -> DistortionCoefficients {

        // Simplified radial distortion estimation
        var coefficients = DistortionCoefficients()

        // Calculate radial errors
        var radialErrors: [(r2: Double, error: Double)] = []

        for i in 0..<known.count {
            let kx = known[i].x - 0.5
            let ky = known[i].y - 0.5
            let mx = measured[i].x - 0.5 - center.x
            let my = measured[i].y - 0.5 - center.y

            let r2 = kx * kx + ky * ky
            let knownR = sqrt(r2)
            let measuredR = sqrt(mx * mx + my * my)

            if knownR > 0.01 {
                let error = (measuredR - knownR) / knownR
                radialErrors.append((r2: r2, error: error))
            }
        }

        // Fit polynomial to errors
        if radialErrors.count >= 3 {
            // Simple linear regression for k1
            let n = Double(radialErrors.count)
            let sumR2 = radialErrors.reduce(0) { $0 + $1.r2 }
            let sumError = radialErrors.reduce(0) { $0 + $1.error }
            let sumR2Error = radialErrors.reduce(0) { $0 + $1.r2 * $1.error }
            let sumR4 = radialErrors.reduce(0) { $0 + $1.r2 * $1.r2 }

            let denominator = n * sumR4 - sumR2 * sumR2
            if abs(denominator) > 1e-10 {
                coefficients.k1 = (n * sumR2Error - sumR2 * sumError) / denominator
            }
        }

        return coefficients
    }

    private func validateCalibration(
        known: [CGPoint],
        measured: [CGPoint],
        centerOffset: CGPoint,
        rotation: Double,
        scale: Double,
        distortion: DistortionCoefficients
    ) -> (CalibrationQuality, Double) {

        var totalError: Double = 0

        for i in 0..<known.count {
            // Apply calibration to known point
            var x = known[i].x - 0.5 - centerOffset.x
            var y = known[i].y - 0.5 - centerOffset.y

            // Rotation
            let rotRad = rotation * .pi / 180.0
            let xRot = x * cos(rotRad) - y * sin(rotRad)
            let yRot = x * sin(rotRad) + y * cos(rotRad)

            // Scale
            let xScaled = xRot * scale + 0.5
            let yScaled = yRot * scale + 0.5

            // Error
            let error = hypot(xScaled - measured[i].x, yScaled - measured[i].y)
            totalError += error
        }

        let avgError = totalError / Double(known.count)

        // Determine quality based on average error
        let quality: CalibrationQuality
        if avgError < 0.005 {
            quality = .excellent
        } else if avgError < 0.01 {
            quality = .good
        } else if avgError < 0.02 {
            quality = .acceptable
        } else {
            quality = .poor
        }

        return (quality, avgError)
    }

    private func centroid(of points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        let sumX = points.reduce(0) { $0 + $1.x }
        let sumY = points.reduce(0) { $0 + $1.y }
        return CGPoint(x: sumX / CGFloat(points.count), y: sumY / CGFloat(points.count))
    }

    // MARK: - Calibration Error
    enum CalibrationError: LocalizedError {
        case insufficientPoints
        case poorQuality
        case processingFailed

        var errorDescription: String? {
            switch self {
            case .insufficientPoints:
                return "São necessários pelo menos 4 pontos de referência"
            case .poorQuality:
                return "Qualidade de calibração insuficiente"
            case .processingFailed:
                return "Falha no processamento da calibração"
            }
        }
    }
}

// MARK: - Calibration Preset Profiles
extension MicroscopeCalibrationService {

    struct CalibrationPreset: Identifiable {
        let id = UUID()
        let name: String
        let description: String
        let data: CalibrationData
    }

    static var presets: [CalibrationPreset] {
        [
            CalibrationPreset(
                name: "MicroRec Padrão",
                description: "Configuração padrão para MicroRec com Zeiss Opmi Lumera I",
                data: CalibrationData(
                    opticalCenterX: 0.0,
                    opticalCenterY: 0.0,
                    rotationOffset: 0.0,
                    scaleFactor: 1.0,
                    k1: -0.05,
                    k2: 0.0,
                    k3: 0.0,
                    p1: 0.0,
                    p2: 0.0,
                    equipmentName: "MicroRec Padrão",
                    microscopeModel: "Zeiss Opmi Lumera I",
                    adapterType: "MicroRec (Custom Surgical)",
                    zoomLevel: 1.0,
                    calibrationDate: Date(),
                    quality: .good,
                    validationError: 0.01
                )
            ),
            CalibrationPreset(
                name: "MicroRec com Zoom 2x",
                description: "Para uso com magnificação 2x no microscópio",
                data: CalibrationData(
                    opticalCenterX: 0.0,
                    opticalCenterY: 0.0,
                    rotationOffset: 0.0,
                    scaleFactor: 2.0,
                    k1: -0.08,
                    k2: 0.02,
                    k3: 0.0,
                    p1: 0.0,
                    p2: 0.0,
                    equipmentName: "MicroRec Zoom 2x",
                    microscopeModel: "Zeiss Opmi Lumera I",
                    adapterType: "MicroRec (Custom Surgical)",
                    zoomLevel: 2.0,
                    calibrationDate: Date(),
                    quality: .good,
                    validationError: 0.012
                )
            )
        ]
    }

    func applyPreset(_ preset: CalibrationPreset) {
        var data = preset.data
        data.calibrationDate = Date()
        calibrationData = data
        saveCalibration()
    }
}
