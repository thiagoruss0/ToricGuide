//
//  SurgicalCase.swift
//  ToricGuide
//
//  Modelo completo de um caso cirúrgico
//

import Foundation
import UIKit

struct SurgicalCase: Identifiable, Codable {
    let id: UUID
    let patientId: UUID

    // Informações básicas
    var eye: Eye
    var surgeryDate: Date

    // Imagem de referência (capturada no consultório)
    var referenceImageData: Data?
    var referenceImageTimestamp: Date?
    var referenceLandmarks: EyeLandmarks?

    // Dados biométricos
    var keratometry: Keratometry?
    var incision: IncisionData?

    // LIO selecionada
    var selectedIOL: ToricIOL?

    // Cálculo do eixo (legado)
    var calculatedAxis: Double? // Eixo calculado em graus
    var residualAstigmatism: Double? // Astigmatismo residual previsto

    // Análise vetorial completa
    var toricAnalysis: StoredToricAnalysis?

    // Configuração do cálculo
    var includesPosteriorAstigmatism: Bool = true

    // Dados intraoperatórios
    var intraopCyclotorsion: Double? // Ciclotorção detectada
    var finalIOLAxis: Double? // Eixo final da LIO implantada

    // Status
    var status: CaseStatus

    // Timestamps
    let createdAt: Date
    var updatedAt: Date
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        patientId: UUID,
        eye: Eye = .right,
        surgeryDate: Date = Date()
    ) {
        self.id = id
        self.patientId = patientId
        self.eye = eye
        self.surgeryDate = surgeryDate
        self.status = .draft
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    mutating func updateTimestamp() {
        updatedAt = Date()
    }
}

// MARK: - Status do Caso
enum CaseStatus: String, Codable {
    case draft = "Rascunho"
    case referenceCapured = "Referência Capturada"
    case calculated = "Calculado"
    case inProgress = "Em Cirurgia"
    case completed = "Concluído"

    var icon: String {
        switch self {
        case .draft: return "doc"
        case .referenceCapured: return "camera.fill"
        case .calculated: return "function"
        case .inProgress: return "eye.fill"
        case .completed: return "checkmark.circle.fill"
        }
    }
}

// MARK: - Landmarks do Olho (para rastreamento)
struct EyeLandmarks: Codable {
    // Centro e raio do limbo
    var limbusCenter: CGPointCodable
    var limbusRadius: CGFloat

    // Centro e raio da pupila
    var pupilCenter: CGPointCodable
    var pupilRadius: CGFloat

    // Vasos limbares detectados (para matching)
    var limbalVessels: [LimbalVessel]

    // Eixo horizontal de referência (do giroscópio)
    var referenceHorizontalAxis: Double // em graus

    // Qualidade da captura
    var captureQuality: CaptureQuality
}

struct LimbalVessel: Codable, Identifiable {
    let id: UUID
    var position: CGPointCodable // Posição relativa ao centro do limbo
    var angle: Double // Ângulo em graus (0-360)
    var length: CGFloat
    var thickness: CGFloat

    init(position: CGPointCodable, angle: Double, length: CGFloat, thickness: CGFloat) {
        self.id = UUID()
        self.position = position
        self.angle = angle
        self.length = length
        self.thickness = thickness
    }
}

enum CaptureQuality: String, Codable {
    case excellent = "Excelente"
    case good = "Boa"
    case acceptable = "Aceitável"
    case poor = "Ruim"

    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .acceptable: return "orange"
        case .poor: return "red"
        }
    }
}

// MARK: - CGPoint Codable wrapper
struct CGPointCodable: Codable {
    var x: CGFloat
    var y: CGFloat

    var cgPoint: CGPoint {
        CGPoint(x: x, y: y)
    }

    init(_ point: CGPoint) {
        self.x = point.x
        self.y = point.y
    }

    init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
    }
}

// MARK: - Análise Tórica Armazenável
/// Versão Codable da análise vetorial para persistência
struct StoredToricAnalysis: Codable {
    // Vetores de astigmatismo
    var anteriorMagnitude: Double
    var anteriorAxis: Double
    var posteriorMagnitude: Double
    var posteriorAxis: Double
    var tcaMagnitude: Double
    var tcaAxis: Double
    var siaMagnitude: Double
    var siaAxis: Double
    var postSIAMagnitude: Double
    var postSIAAxis: Double
    var residualMagnitude: Double
    var residualAxis: Double

    // Eixo de implantação
    var implantationAxis: Double

    // Tipo de correção
    var correctionTypeRaw: String

    // Porcentagem de correção
    var correctionPercentage: Double

    // Eye
    var eyeRaw: String

    // Construtor a partir de FullToricAnalysis
    init(from analysis: FullToricAnalysis) {
        self.anteriorMagnitude = analysis.anteriorAstigmatism.magnitude
        self.anteriorAxis = analysis.anteriorAstigmatism.axis
        self.posteriorMagnitude = analysis.posteriorAstigmatism.magnitude
        self.posteriorAxis = analysis.posteriorAstigmatism.axis
        self.tcaMagnitude = analysis.totalCornealAstigmatism.magnitude
        self.tcaAxis = analysis.totalCornealAstigmatism.axis
        self.siaMagnitude = analysis.surgicallyInducedAstigmatism.magnitude
        self.siaAxis = analysis.surgicallyInducedAstigmatism.axis
        self.postSIAMagnitude = analysis.postSIAAstigmatism.magnitude
        self.postSIAAxis = analysis.postSIAAstigmatism.axis
        self.residualMagnitude = analysis.residualAstigmatism.magnitude
        self.residualAxis = analysis.residualAstigmatism.axis
        self.implantationAxis = analysis.implantationAxis
        self.correctionTypeRaw = analysis.correctionType.rawValue
        self.correctionPercentage = analysis.correctionPercentage
        self.eyeRaw = analysis.eye.rawValue
    }

    // Propriedades formatadas
    var anteriorFormatted: String {
        String(format: "%.2fD @ %.0f°", anteriorMagnitude, anteriorAxis)
    }

    var posteriorFormatted: String {
        String(format: "%.2fD @ %.0f°", posteriorMagnitude, posteriorAxis)
    }

    var tcaFormatted: String {
        String(format: "%.2fD @ %.0f°", tcaMagnitude, tcaAxis)
    }

    var siaFormatted: String {
        String(format: "%.2fD @ %.0f°", siaMagnitude, siaAxis)
    }

    var postSIAFormatted: String {
        String(format: "%.2fD @ %.0f°", postSIAMagnitude, postSIAAxis)
    }

    var residualFormatted: String {
        String(format: "%.2fD @ %.0f°", residualMagnitude, residualAxis)
    }

    var correctionType: String {
        switch correctionTypeRaw {
        case "undercorrection": return "Subcorreção"
        case "exact": return "Correção Exata"
        case "overcorrection": return "Hipercorreção"
        default: return correctionTypeRaw
        }
    }

    var isOvercorrection: Bool {
        correctionTypeRaw == "overcorrection"
    }

    var isUndercorrection: Bool {
        correctionTypeRaw == "undercorrection"
    }
}
