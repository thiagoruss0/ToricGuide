//
//  Keratometry.swift
//  ToricGuide
//
//  Dados de ceratometria e incisão
//

import Foundation

// MARK: - Ceratometria
struct Keratometry: Codable {
    // K1 - Meridiano mais plano
    var k1Power: Double // em Dioptrias
    var k1Axis: Double  // em graus (0-180)

    // K2 - Meridiano mais curvo
    var k2Power: Double // em Dioptrias
    var k2Axis: Double  // em graus (0-180)

    // Calculados automaticamente
    var totalCornealAstigmatism: Double {
        abs(k2Power - k1Power)
    }

    // Eixo do astigmatismo (eixo do meridiano mais curvo)
    var astigmatismAxis: Double {
        k2Axis
    }

    // Tipo de astigmatismo
    var astigmatismType: AstigmatismType {
        // WTR: eixo mais curvo próximo de 90° (80-100)
        // ATR: eixo mais curvo próximo de 180° (0-10 ou 170-180)
        // Oblíquo: outros eixos
        if k2Axis >= 80 && k2Axis <= 100 {
            return .withTheRule
        } else if k2Axis <= 10 || k2Axis >= 170 {
            return .againstTheRule
        } else {
            return .oblique
        }
    }

    // Validação
    var isValid: Bool {
        k1Power > 30 && k1Power < 60 &&
        k2Power > 30 && k2Power < 60 &&
        k1Axis >= 0 && k1Axis <= 180 &&
        k2Axis >= 0 && k2Axis <= 180
    }

    init(k1Power: Double = 43.0, k1Axis: Double = 180,
         k2Power: Double = 44.0, k2Axis: Double = 90) {
        self.k1Power = k1Power
        self.k1Axis = k1Axis
        self.k2Power = k2Power
        self.k2Axis = k2Axis
    }
}

enum AstigmatismType: String, Codable {
    case withTheRule = "A Favor da Regra"    // WTR
    case againstTheRule = "Contra a Regra"  // ATR
    case oblique = "Oblíquo"

    var abbreviation: String {
        switch self {
        case .withTheRule: return "WTR"
        case .againstTheRule: return "ATR"
        case .oblique: return "OBL"
        }
    }
}

// MARK: - Dados da Incisão
struct IncisionData: Codable {
    var location: IncisionLocation
    var axis: Double // Eixo da incisão em graus
    var size: Double // Tamanho em mm
    var surgicallyInducedAstigmatism: Double // SIA em Dioptrias

    init(
        location: IncisionLocation = .temporal,
        axis: Double = 180,
        size: Double = 2.4,
        surgicallyInducedAstigmatism: Double = 0.30
    ) {
        self.location = location
        self.axis = axis
        self.size = size
        self.surgicallyInducedAstigmatism = surgicallyInducedAstigmatism
    }
}

enum IncisionLocation: String, Codable, CaseIterable {
    case temporal = "Temporal"
    case superior = "Superior"
    case nasal = "Nasal"
    case onAxis = "No Eixo"

    // Eixo típico para cada localização (OD)
    func typicalAxis(for eye: Eye) -> Double {
        switch self {
        case .temporal:
            return eye == .right ? 180 : 0
        case .superior:
            return 90
        case .nasal:
            return eye == .right ? 0 : 180
        case .onAxis:
            return 0 // Será definido pelo usuário
        }
    }
}

// MARK: - Tamanhos de incisão comuns
struct IncisionSizes {
    static let common: [Double] = [2.0, 2.2, 2.4, 2.6, 2.75, 3.0]

    static func siaForSize(_ size: Double) -> Double {
        // Valores aproximados de SIA por tamanho de incisão
        switch size {
        case ...2.0: return 0.15
        case 2.0..<2.4: return 0.25
        case 2.4..<2.75: return 0.35
        case 2.75..<3.0: return 0.45
        default: return 0.50
        }
    }
}
