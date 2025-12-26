//
//  ToricCalculator.swift
//  ToricGuide
//
//  Calculadora de eixo de implantação de LIO tórica
//  Implementa cálculo vetorial completo (Double-Angle Vector Analysis)
//
//  Baseado em:
//  - Alpins Method para análise vetorial
//  - Holladay para cálculo de SIA
//  - Baylor Nomogram para astigmatismo posterior
//

import Foundation

// MARK: - ToricCalculator Principal
struct ToricCalculator {

    // MARK: - Constantes Clínicas
    struct Constants {
        // Fator de conversão plano corneano para plano IOL (média)
        static let cornealToIOLFactor: Double = 1.46

        // Astigmatismo posterior estimado (Baylor Nomogram)
        // WTR: -0.50D, ATR: +0.25D, Oblíquo: -0.13D
        static let posteriorAstigmatismWTR: Double = -0.50
        static let posteriorAstigmatismATR: Double = 0.25
        static let posteriorAstigmatismOblique: Double = -0.13

        // Threshold para considerar alinhamento aceitável
        static let acceptableMisalignment: Double = 5.0 // graus

        // Porcentagem de perda por grau de desalinhamento
        static let lossPerDegree: Double = 3.3 // ~3.3% por grau
    }

    // MARK: - Cálculo Completo do Eixo

    /// Calcula o eixo de implantação usando análise vetorial completa
    /// - Parameters:
    ///   - keratometry: Dados de ceratometria (K1, K2)
    ///   - incision: Dados da incisão (localização, SIA)
    ///   - iol: LIO tórica selecionada
    ///   - eye: Olho a ser operado (OD/OE) - importante para SIA
    ///   - includePostAstig: Incluir estimativa de astigmatismo posterior
    /// - Returns: Resultado completo do cálculo
    static func calculateFullAnalysis(
        keratometry: Keratometry,
        incision: IncisionData,
        iol: ToricIOL,
        eye: Eye,
        includePostAstig: Bool = true
    ) -> FullToricAnalysis {

        // 1. Calcular astigmatismo corneano anterior
        let anteriorAstig = AstigmatismVector(
            magnitude: keratometry.totalCornealAstigmatism,
            axis: keratometry.astigmatismAxis
        )

        // 2. Estimar astigmatismo posterior (Baylor Nomogram)
        let posteriorAstig: AstigmatismVector
        if includePostAstig {
            posteriorAstig = estimatePosteriorAstigmatism(
                anteriorAstig: anteriorAstig,
                astigType: keratometry.astigmatismType
            )
        } else {
            posteriorAstig = AstigmatismVector(magnitude: 0, axis: 0)
        }

        // 3. Calcular TCA (Total Corneal Astigmatism)
        let tca = addAstigmatismVectors(anteriorAstig, posteriorAstig)

        // 4. Calcular SIA (Surgically Induced Astigmatism)
        let siaAxis = calculateSIAAxis(incisionLocation: incision.location, eye: eye)
        let sia = AstigmatismVector(
            magnitude: incision.surgicallyInducedAstigmatism,
            axis: siaAxis
        )

        // 5. Calcular astigmatismo pós-SIA (TCA + SIA)
        let postSIAAstig = addAstigmatismVectors(tca, sia)

        // 6. Determinar eixo de implantação
        // O eixo da LIO deve ser alinhado com o meridiano mais curvo
        let implantationAxis = postSIAAstig.axis

        // 7. Calcular astigmatismo residual previsto
        let iolCylinderAtCornea = iol.cylinderPowerAtCornea
        let residualMagnitude = abs(postSIAAstig.magnitude - iolCylinderAtCornea)

        // 8. Determinar se overcorrection ou undercorrection
        let correctionType: CorrectionType
        if iolCylinderAtCornea > postSIAAstig.magnitude {
            correctionType = .overcorrection
        } else if iolCylinderAtCornea < postSIAAstig.magnitude {
            correctionType = .undercorrection
        } else {
            correctionType = .exact
        }

        // 9. Calcular flipping do eixo se overcorrection
        let finalAxis: Double
        let residualAxis: Double
        if correctionType == .overcorrection {
            // Em overcorrection, o eixo residual é perpendicular
            finalAxis = implantationAxis
            residualAxis = normalizeAxis(implantationAxis + 90)
        } else {
            finalAxis = implantationAxis
            residualAxis = implantationAxis
        }

        return FullToricAnalysis(
            anteriorAstigmatism: anteriorAstig,
            posteriorAstigmatism: posteriorAstig,
            totalCornealAstigmatism: tca,
            surgicallyInducedAstigmatism: sia,
            postSIAAstigmatism: postSIAAstig,
            implantationAxis: finalAxis,
            residualAstigmatism: AstigmatismVector(magnitude: residualMagnitude, axis: residualAxis),
            correctionType: correctionType,
            selectedIOL: iol,
            eye: eye
        )
    }

    // MARK: - Cálculo Simplificado (Legado)

    static func calculateImplantationAxis(
        keratometry: Keratometry,
        incision: IncisionData,
        iol: ToricIOL
    ) -> ToricCalculationResult {
        let analysis = calculateFullAnalysis(
            keratometry: keratometry,
            incision: incision,
            iol: iol,
            eye: .right,
            includePostAstig: false
        )

        return ToricCalculationResult(
            implantationAxis: analysis.implantationAxis,
            targetAstigmatism: analysis.postSIAAstigmatism.magnitude,
            predictedResidualAstigmatism: analysis.residualAstigmatism.magnitude,
            siaEffect: incision.surgicallyInducedAstigmatism,
            originalCornealAstigmatism: keratometry.totalCornealAstigmatism,
            selectedIOL: iol
        )
    }

    // MARK: - Estimativa de Astigmatismo Posterior

    private static func estimatePosteriorAstigmatism(
        anteriorAstig: AstigmatismVector,
        astigType: AstigmatismType
    ) -> AstigmatismVector {
        // Baseado no Baylor Nomogram
        let posteriorMagnitude: Double
        let posteriorAxis: Double

        switch astigType {
        case .withTheRule:
            // WTR: posterior é ATR, reduz o astigmatismo total
            posteriorMagnitude = abs(Constants.posteriorAstigmatismWTR)
            posteriorAxis = normalizeAxis(anteriorAstig.axis + 90)

        case .againstTheRule:
            // ATR: posterior é WTR, aumenta o astigmatismo total
            posteriorMagnitude = Constants.posteriorAstigmatismATR
            posteriorAxis = normalizeAxis(anteriorAstig.axis + 90)

        case .oblique:
            posteriorMagnitude = abs(Constants.posteriorAstigmatismOblique)
            posteriorAxis = normalizeAxis(anteriorAstig.axis + 90)
        }

        return AstigmatismVector(magnitude: posteriorMagnitude, axis: posteriorAxis)
    }

    // MARK: - Cálculo do Eixo do SIA

    private static func calculateSIAAxis(incisionLocation: IncisionLocation, eye: Eye) -> Double {
        switch incisionLocation {
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

    // MARK: - Análise Vetorial (Double-Angle Method)

    /// Converte astigmatismo para representação vetorial (double-angle)
    static func astigmatismToVector(_ astig: AstigmatismVector) -> (x: Double, y: Double) {
        let theta = 2 * astig.axis * .pi / 180
        let x = astig.magnitude * cos(theta)
        let y = astig.magnitude * sin(theta)
        return (x, y)
    }

    /// Converte vetor para astigmatismo
    static func vectorToAstigmatism(_ vector: (x: Double, y: Double)) -> AstigmatismVector {
        let magnitude = sqrt(vector.x * vector.x + vector.y * vector.y)
        var theta = atan2(vector.y, vector.x)
        if theta < 0 {
            theta += 2 * .pi
        }
        let axis = normalizeAxis((theta * 180 / .pi) / 2)
        return AstigmatismVector(magnitude: magnitude, axis: axis)
    }

    /// Soma dois vetores de astigmatismo
    static func addAstigmatismVectors(
        _ v1: AstigmatismVector,
        _ v2: AstigmatismVector
    ) -> AstigmatismVector {
        let vec1 = astigmatismToVector(v1)
        let vec2 = astigmatismToVector(v2)
        let sumVector = (x: vec1.x + vec2.x, y: vec1.y + vec2.y)
        return vectorToAstigmatism(sumVector)
    }

    /// Subtrai vetores de astigmatismo (v1 - v2)
    static func subtractAstigmatismVectors(
        _ v1: AstigmatismVector,
        _ v2: AstigmatismVector
    ) -> AstigmatismVector {
        let vec1 = astigmatismToVector(v1)
        let vec2 = astigmatismToVector(v2)
        let diffVector = (x: vec1.x - vec2.x, y: vec1.y - vec2.y)
        return vectorToAstigmatism(diffVector)
    }

    // MARK: - Normalização de Eixo

    static func normalizeAxis(_ axis: Double) -> Double {
        var normalized = axis.truncatingRemainder(dividingBy: 180)
        if normalized < 0 {
            normalized += 180
        }
        return normalized
    }

    // MARK: - Correção de Ciclotorção

    /// Corrige o eixo considerando ciclotorção detectada
    static func correctForCyclotorsion(
        originalAxis: Double,
        cyclotorsion: Double,
        eye: Eye
    ) -> CyclotorsionCorrection {
        // A ciclotorção é a rotação do olho quando o paciente deita
        // Típico: 2-5° de exciclotorção (rotação para fora)

        // Para OD: exciclotorção = rotação anti-horária
        // Para OE: exciclotorção = rotação horária

        let adjustedCyclotorsion = eye == .right ? -cyclotorsion : cyclotorsion
        let correctedAxis = normalizeAxis(originalAxis + adjustedCyclotorsion)

        return CyclotorsionCorrection(
            originalAxis: originalAxis,
            cyclotorsionDetected: cyclotorsion,
            correctedAxis: correctedAxis,
            eye: eye
        )
    }

    // MARK: - Análise de Desalinhamento

    /// Calcula o efeito do desalinhamento da LIO
    static func calculateMisalignmentEffect(
        misalignment: Double,
        iolCylinder: Double
    ) -> MisalignmentEffect {
        let absError = abs(misalignment)

        // Fórmula: Astigmatismo residual = 2 × IOL_cylinder × sin(erro)
        let residualFromError = 2 * iolCylinder * sin(absError * .pi / 180)

        // Correção efetiva restante
        let effectiveCorrection = iolCylinder * cos(2 * absError * .pi / 180)

        // Porcentagem perdida
        let percentageLost = (1 - cos(2 * absError * .pi / 180)) * 100

        // Em 30° de erro, 100% da correção é perdida e inverte o eixo
        let isSignificant = absError >= 10
        let isCritical = absError >= 30

        return MisalignmentEffect(
            misalignmentDegrees: misalignment,
            residualAstigmatism: residualFromError,
            percentageCorrectionLost: percentageLost,
            effectiveCorrection: effectiveCorrection,
            isSignificant: isSignificant,
            isCritical: isCritical
        )
    }

    // MARK: - Recomendação de LIO

    /// Encontra as melhores opções de LIO
    static func recommendIOLs(
        targetAstigmatism: Double,
        manufacturer: IOLManufacturer? = nil,
        preferUndercorrection: Bool = true,
        maxResidual: Double = 0.75
    ) -> [IOLRecommendation] {
        let candidates = manufacturer.map { IOLCatalog.models(for: $0) } ?? IOLCatalog.all

        var recommendations = candidates.compactMap { iol -> IOLRecommendation? in
            let residual = targetAstigmatism - iol.cylinderPowerAtCornea
            let absResidual = abs(residual)

            // Filtrar opções muito fora
            guard absResidual < maxResidual else { return nil }

            let isOvercorrection = residual < 0
            let isOptimal = absResidual < 0.50

            // Penalizar overcorrection se preferir undercorrection
            let score: Double
            if preferUndercorrection && isOvercorrection {
                score = absResidual + 0.25 // Penalidade
            } else {
                score = absResidual
            }

            return IOLRecommendation(
                iol: iol,
                predictedResidual: absResidual,
                isOvercorrection: isOvercorrection,
                isOptimal: isOptimal,
                score: score
            )
        }

        // Ordenar por score
        recommendations.sort { $0.score < $1.score }

        return recommendations
    }

    // MARK: - Simulação Visual

    /// Gera pontos para desenhar a representação gráfica
    static func generateAxisVisualization(
        targetAxis: Double,
        currentAxis: Double,
        radius: Double = 100
    ) -> AxisVisualization {
        let targetRadians = (90 - targetAxis) * .pi / 180
        let currentRadians = (90 - currentAxis) * .pi / 180

        let targetEnd = CGPoint(
            x: radius * cos(targetRadians),
            y: -radius * sin(targetRadians)
        )
        let currentEnd = CGPoint(
            x: radius * cos(currentRadians),
            y: -radius * sin(currentRadians)
        )

        let deviation = abs(currentAxis - targetAxis)
        let isAligned = deviation < Constants.acceptableMisalignment

        return AxisVisualization(
            targetAxis: targetAxis,
            targetEndPoint: targetEnd,
            currentAxis: currentAxis,
            currentEndPoint: currentEnd,
            deviation: deviation,
            isAligned: isAligned
        )
    }
}

// MARK: - Estruturas de Dados

/// Vetor de astigmatismo
struct AstigmatismVector {
    let magnitude: Double  // Dioptrias
    let axis: Double       // Graus (0-180)

    var formattedString: String {
        String(format: "%.2fD @ %.0f°", magnitude, axis)
    }
}

/// Tipo de correção
enum CorrectionType {
    case undercorrection  // LIO menor que necessário
    case exact            // Correção exata
    case overcorrection   // LIO maior que necessário (causa flip de eixo)

    var description: String {
        switch self {
        case .undercorrection: return "Subcorreção"
        case .exact: return "Correção Exata"
        case .overcorrection: return "Hipercorreção"
        }
    }
}

/// Análise completa do cálculo tórico
struct FullToricAnalysis {
    let anteriorAstigmatism: AstigmatismVector
    let posteriorAstigmatism: AstigmatismVector
    let totalCornealAstigmatism: AstigmatismVector
    let surgicallyInducedAstigmatism: AstigmatismVector
    let postSIAAstigmatism: AstigmatismVector
    let implantationAxis: Double
    let residualAstigmatism: AstigmatismVector
    let correctionType: CorrectionType
    let selectedIOL: ToricIOL
    let eye: Eye

    /// Porcentagem de correção alcançada
    var correctionPercentage: Double {
        guard totalCornealAstigmatism.magnitude > 0 else { return 100 }
        let corrected = totalCornealAstigmatism.magnitude - residualAstigmatism.magnitude
        return (corrected / totalCornealAstigmatism.magnitude) * 100
    }

    /// Resumo textual
    var summary: String {
        """
        Astig. Anterior: \(anteriorAstigmatism.formattedString)
        Astig. Posterior: \(posteriorAstigmatism.formattedString)
        TCA: \(totalCornealAstigmatism.formattedString)
        SIA: \(surgicallyInducedAstigmatism.formattedString)
        Pós-SIA: \(postSIAAstigmatism.formattedString)
        Eixo de Implantação: \(Int(implantationAxis))°
        Residual Previsto: \(residualAstigmatism.formattedString)
        Correção: \(correctionType.description) (\(String(format: "%.0f", correctionPercentage))%)
        """
    }
}

/// Correção de ciclotorção
struct CyclotorsionCorrection {
    let originalAxis: Double
    let cyclotorsionDetected: Double
    let correctedAxis: Double
    let eye: Eye

    var description: String {
        "Eixo \(Int(originalAxis))° → \(Int(correctedAxis))° (ciclotorção: \(String(format: "%+.1f", cyclotorsionDetected))°)"
    }
}

/// Resultado simplificado (compatibilidade)
struct ToricCalculationResult {
    let implantationAxis: Double
    let targetAstigmatism: Double
    let predictedResidualAstigmatism: Double
    let siaEffect: Double
    let originalCornealAstigmatism: Double
    let selectedIOL: ToricIOL

    var correctionPercentage: Double {
        guard originalCornealAstigmatism > 0 else { return 0 }
        return ((originalCornealAstigmatism - predictedResidualAstigmatism) / originalCornealAstigmatism) * 100
    }
}

/// Efeito de desalinhamento
struct MisalignmentEffect {
    let misalignmentDegrees: Double
    let residualAstigmatism: Double
    let percentageCorrectionLost: Double
    let effectiveCorrection: Double
    let isSignificant: Bool
    let isCritical: Bool

    var description: String {
        if isCritical {
            return "CRÍTICO: Desalinhamento de \(Int(abs(misalignmentDegrees)))° - correção perdida!"
        } else if isSignificant {
            return "Desalinhamento de \(Int(abs(misalignmentDegrees)))°: \(Int(percentageCorrectionLost))% da correção perdida"
        } else {
            return "Alinhamento aceitável (desvio: \(Int(abs(misalignmentDegrees)))°)"
        }
    }

    var statusColor: String {
        if isCritical { return "red" }
        if isSignificant { return "orange" }
        return "green"
    }
}

/// Recomendação de LIO
struct IOLRecommendation {
    let iol: ToricIOL
    let predictedResidual: Double
    let isOvercorrection: Bool
    let isOptimal: Bool
    let score: Double

    var description: String {
        let correctionType = isOvercorrection ? "hiper" : "sub"
        return "\(iol.shortName) - Residual: \(String(format: "%.2f", predictedResidual))D (\(correctionType))"
    }
}

/// Visualização do eixo
struct AxisVisualization {
    let targetAxis: Double
    let targetEndPoint: CGPoint
    let currentAxis: Double
    let currentEndPoint: CGPoint
    let deviation: Double
    let isAligned: Bool
}
