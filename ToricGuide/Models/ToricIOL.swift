//
//  ToricIOL.swift
//  ToricGuide
//
//  Modelos de lentes intraoculares tóricas
//

import Foundation

// MARK: - LIO Tórica
struct ToricIOL: Identifiable, Codable, Hashable {
    let id: UUID
    let manufacturer: IOLManufacturer
    let model: String
    let platform: String

    // Poder cilíndrico
    let cylinderPowerAtIOL: Double      // No plano da LIO
    let cylinderPowerAtCornea: Double   // No plano corneano (para comparação)

    // Código do modelo (ex: T3, T4, T5...)
    let toricity: String

    // Faixa de poderes esféricos disponíveis
    let sphericalPowerRange: ClosedRange<Double>

    // Constante A
    let aConstant: Double

    init(
        id: UUID = UUID(),
        manufacturer: IOLManufacturer,
        model: String,
        platform: String,
        cylinderPowerAtIOL: Double,
        cylinderPowerAtCornea: Double,
        toricity: String,
        sphericalPowerRange: ClosedRange<Double> = 6.0...30.0,
        aConstant: Double = 118.7
    ) {
        self.id = id
        self.manufacturer = manufacturer
        self.model = model
        self.platform = platform
        self.cylinderPowerAtIOL = cylinderPowerAtIOL
        self.cylinderPowerAtCornea = cylinderPowerAtCornea
        self.toricity = toricity
        self.sphericalPowerRange = sphericalPowerRange
        self.aConstant = aConstant
    }

    var fullName: String {
        "\(manufacturer.rawValue) \(model) \(toricity)"
    }

    var shortName: String {
        "\(platform)\(toricity)"
    }
}

// MARK: - Fabricantes
enum IOLManufacturer: String, Codable, CaseIterable {
    case alcon = "Alcon"
    case johnsonJohnson = "J&J Vision"
    case zeiss = "Zeiss"
    case bauschLomb = "Bausch+Lomb"

    var models: [String] {
        switch self {
        case .alcon:
            return ["AcrySof IQ Toric", "Clareon Toric", "PanOptix Toric"]
        case .johnsonJohnson:
            return ["Tecnis Toric II", "Tecnis Symfony Toric", "Tecnis Synergy Toric"]
        case .zeiss:
            return ["AT TORBI 709M", "AT LISA tri toric 939MP"]
        case .bauschLomb:
            return ["enVista Toric"]
        }
    }
}

// MARK: - Catálogo de LIOs Tóricas
struct IOLCatalog {

    // MARK: - Alcon AcrySof IQ Toric (SN6AT)
    static let alconAcrySofToric: [ToricIOL] = [
        ToricIOL(manufacturer: .alcon, model: "AcrySof IQ Toric", platform: "SN6AT",
                 cylinderPowerAtIOL: 1.03, cylinderPowerAtCornea: 0.69, toricity: "T3"),
        ToricIOL(manufacturer: .alcon, model: "AcrySof IQ Toric", platform: "SN6AT",
                 cylinderPowerAtIOL: 1.55, cylinderPowerAtCornea: 1.03, toricity: "T4"),
        ToricIOL(manufacturer: .alcon, model: "AcrySof IQ Toric", platform: "SN6AT",
                 cylinderPowerAtIOL: 2.06, cylinderPowerAtCornea: 1.38, toricity: "T5"),
        ToricIOL(manufacturer: .alcon, model: "AcrySof IQ Toric", platform: "SN6AT",
                 cylinderPowerAtIOL: 2.57, cylinderPowerAtCornea: 1.72, toricity: "T6"),
        ToricIOL(manufacturer: .alcon, model: "AcrySof IQ Toric", platform: "SN6AT",
                 cylinderPowerAtIOL: 3.08, cylinderPowerAtCornea: 2.06, toricity: "T7"),
        ToricIOL(manufacturer: .alcon, model: "AcrySof IQ Toric", platform: "SN6AT",
                 cylinderPowerAtIOL: 3.60, cylinderPowerAtCornea: 2.41, toricity: "T8"),
        ToricIOL(manufacturer: .alcon, model: "AcrySof IQ Toric", platform: "SN6AT",
                 cylinderPowerAtIOL: 4.11, cylinderPowerAtCornea: 2.75, toricity: "T9"),
    ]

    // MARK: - Alcon Clareon Toric (CNWTT)
    static let alconClareonToric: [ToricIOL] = [
        ToricIOL(manufacturer: .alcon, model: "Clareon Toric", platform: "CNWTT",
                 cylinderPowerAtIOL: 1.00, cylinderPowerAtCornea: 0.68, toricity: "T3", aConstant: 119.1),
        ToricIOL(manufacturer: .alcon, model: "Clareon Toric", platform: "CNWTT",
                 cylinderPowerAtIOL: 1.50, cylinderPowerAtCornea: 1.01, toricity: "T4", aConstant: 119.1),
        ToricIOL(manufacturer: .alcon, model: "Clareon Toric", platform: "CNWTT",
                 cylinderPowerAtIOL: 2.25, cylinderPowerAtCornea: 1.52, toricity: "T5", aConstant: 119.1),
        ToricIOL(manufacturer: .alcon, model: "Clareon Toric", platform: "CNWTT",
                 cylinderPowerAtIOL: 3.00, cylinderPowerAtCornea: 2.03, toricity: "T6", aConstant: 119.1),
        ToricIOL(manufacturer: .alcon, model: "Clareon Toric", platform: "CNWTT",
                 cylinderPowerAtIOL: 3.75, cylinderPowerAtCornea: 2.53, toricity: "T7", aConstant: 119.1),
        ToricIOL(manufacturer: .alcon, model: "Clareon Toric", platform: "CNWTT",
                 cylinderPowerAtIOL: 4.50, cylinderPowerAtCornea: 3.04, toricity: "T8", aConstant: 119.1),
        ToricIOL(manufacturer: .alcon, model: "Clareon Toric", platform: "CNWTT",
                 cylinderPowerAtIOL: 5.25, cylinderPowerAtCornea: 3.55, toricity: "T9", aConstant: 119.1),
    ]

    // MARK: - J&J Tecnis Toric II (ZCT)
    static let tecnisToricII: [ToricIOL] = [
        ToricIOL(manufacturer: .johnsonJohnson, model: "Tecnis Toric II", platform: "ZCT",
                 cylinderPowerAtIOL: 1.00, cylinderPowerAtCornea: 0.69, toricity: "100", aConstant: 119.3),
        ToricIOL(manufacturer: .johnsonJohnson, model: "Tecnis Toric II", platform: "ZCT",
                 cylinderPowerAtIOL: 1.50, cylinderPowerAtCornea: 1.03, toricity: "150", aConstant: 119.3),
        ToricIOL(manufacturer: .johnsonJohnson, model: "Tecnis Toric II", platform: "ZCT",
                 cylinderPowerAtIOL: 2.25, cylinderPowerAtCornea: 1.55, toricity: "225", aConstant: 119.3),
        ToricIOL(manufacturer: .johnsonJohnson, model: "Tecnis Toric II", platform: "ZCT",
                 cylinderPowerAtIOL: 3.00, cylinderPowerAtCornea: 2.06, toricity: "300", aConstant: 119.3),
        ToricIOL(manufacturer: .johnsonJohnson, model: "Tecnis Toric II", platform: "ZCT",
                 cylinderPowerAtIOL: 3.75, cylinderPowerAtCornea: 2.58, toricity: "375", aConstant: 119.3),
        ToricIOL(manufacturer: .johnsonJohnson, model: "Tecnis Toric II", platform: "ZCT",
                 cylinderPowerAtIOL: 4.00, cylinderPowerAtCornea: 2.75, toricity: "400", aConstant: 119.3),
    ]

    // MARK: - Zeiss AT TORBI 709M
    static let zeissATTorbi: [ToricIOL] = [
        ToricIOL(manufacturer: .zeiss, model: "AT TORBI 709M", platform: "709M",
                 cylinderPowerAtIOL: 1.00, cylinderPowerAtCornea: 0.67, toricity: "T10", aConstant: 118.3),
        ToricIOL(manufacturer: .zeiss, model: "AT TORBI 709M", platform: "709M",
                 cylinderPowerAtIOL: 1.50, cylinderPowerAtCornea: 1.00, toricity: "T15", aConstant: 118.3),
        ToricIOL(manufacturer: .zeiss, model: "AT TORBI 709M", platform: "709M",
                 cylinderPowerAtIOL: 2.00, cylinderPowerAtCornea: 1.33, toricity: "T20", aConstant: 118.3),
        ToricIOL(manufacturer: .zeiss, model: "AT TORBI 709M", platform: "709M",
                 cylinderPowerAtIOL: 2.50, cylinderPowerAtCornea: 1.67, toricity: "T25", aConstant: 118.3),
        ToricIOL(manufacturer: .zeiss, model: "AT TORBI 709M", platform: "709M",
                 cylinderPowerAtIOL: 3.00, cylinderPowerAtCornea: 2.00, toricity: "T30", aConstant: 118.3),
        ToricIOL(manufacturer: .zeiss, model: "AT TORBI 709M", platform: "709M",
                 cylinderPowerAtIOL: 4.00, cylinderPowerAtCornea: 2.67, toricity: "T40", aConstant: 118.3),
        ToricIOL(manufacturer: .zeiss, model: "AT TORBI 709M", platform: "709M",
                 cylinderPowerAtIOL: 5.00, cylinderPowerAtCornea: 3.33, toricity: "T50", aConstant: 118.3),
        ToricIOL(manufacturer: .zeiss, model: "AT TORBI 709M", platform: "709M",
                 cylinderPowerAtIOL: 6.00, cylinderPowerAtCornea: 4.00, toricity: "T60", aConstant: 118.3),
        // Zeiss vai até 12D!
        ToricIOL(manufacturer: .zeiss, model: "AT TORBI 709M", platform: "709M",
                 cylinderPowerAtIOL: 9.00, cylinderPowerAtCornea: 6.00, toricity: "T90", aConstant: 118.3),
        ToricIOL(manufacturer: .zeiss, model: "AT TORBI 709M", platform: "709M",
                 cylinderPowerAtIOL: 12.00, cylinderPowerAtCornea: 8.00, toricity: "T120", aConstant: 118.3),
    ]

    // MARK: - Bausch+Lomb enVista Toric (MX60T)
    static let bauschLombEnvista: [ToricIOL] = [
        ToricIOL(manufacturer: .bauschLomb, model: "enVista Toric", platform: "MX60T",
                 cylinderPowerAtIOL: 1.25, cylinderPowerAtCornea: 0.86, toricity: "T1", aConstant: 118.0),
        ToricIOL(manufacturer: .bauschLomb, model: "enVista Toric", platform: "MX60T",
                 cylinderPowerAtIOL: 2.00, cylinderPowerAtCornea: 1.38, toricity: "T2", aConstant: 118.0),
        ToricIOL(manufacturer: .bauschLomb, model: "enVista Toric", platform: "MX60T",
                 cylinderPowerAtIOL: 2.75, cylinderPowerAtCornea: 1.89, toricity: "T3", aConstant: 118.0),
        ToricIOL(manufacturer: .bauschLomb, model: "enVista Toric", platform: "MX60T",
                 cylinderPowerAtIOL: 3.50, cylinderPowerAtCornea: 2.41, toricity: "T4", aConstant: 118.0),
        ToricIOL(manufacturer: .bauschLomb, model: "enVista Toric", platform: "MX60T",
                 cylinderPowerAtIOL: 4.25, cylinderPowerAtCornea: 2.93, toricity: "T5", aConstant: 118.0),
        ToricIOL(manufacturer: .bauschLomb, model: "enVista Toric", platform: "MX60T",
                 cylinderPowerAtIOL: 5.00, cylinderPowerAtCornea: 3.44, toricity: "T6", aConstant: 118.0),
        ToricIOL(manufacturer: .bauschLomb, model: "enVista Toric", platform: "MX60T",
                 cylinderPowerAtIOL: 5.75, cylinderPowerAtCornea: 3.96, toricity: "T7", aConstant: 118.0),
    ]

    // MARK: - Todos os modelos
    static var all: [ToricIOL] {
        alconAcrySofToric + alconClareonToric + tecnisToricII + zeissATTorbi + bauschLombEnvista
    }

    // MARK: - Filtrar por fabricante
    static func models(for manufacturer: IOLManufacturer) -> [ToricIOL] {
        all.filter { $0.manufacturer == manufacturer }
    }

    // MARK: - Encontrar LIO ideal para um astigmatismo
    static func findBestMatch(
        targetCornealCylinder: Double,
        manufacturer: IOLManufacturer? = nil
    ) -> ToricIOL? {
        let candidates = manufacturer.map { models(for: $0) } ?? all

        return candidates.min { lhs, rhs in
            abs(lhs.cylinderPowerAtCornea - targetCornealCylinder) <
            abs(rhs.cylinderPowerAtCornea - targetCornealCylinder)
        }
    }

    // MARK: - Encontrar opções próximas
    static func findOptions(
        targetCornealCylinder: Double,
        manufacturer: IOLManufacturer? = nil,
        count: Int = 3
    ) -> [ToricIOL] {
        let candidates = manufacturer.map { models(for: $0) } ?? all

        return candidates
            .sorted { abs($0.cylinderPowerAtCornea - targetCornealCylinder) <
                     abs($1.cylinderPowerAtCornea - targetCornealCylinder) }
            .prefix(count)
            .map { $0 }
    }
}
