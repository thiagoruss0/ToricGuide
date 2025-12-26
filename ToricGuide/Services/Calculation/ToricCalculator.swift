//
//  ToricCalculator.swift
//  ToricGuide
//
//  Calculadora de eixo de implantação de LIO tórica
//  Implementa cálculo vetorial para SIA e astigmatismo residual
//

import Foundation

struct ToricCalculator {

    // MARK: - Cálculo Principal

    /// Calcula o eixo de implantação da LIO tórica
    /// - Parameters:
    ///   - keratometry: Dados de ceratometria
    ///   - incision: Dados da incisão
    ///   - iol: LIO tórica selecionada
    /// - Returns: Resultado do cálculo
    static func calculateImplantationAxis(
        keratometry: Keratometry,
        incision: IncisionData,
        iol: ToricIOL
    ) -> ToricCalculationResult {

        // 1. Converter astigmatismo corneano para vetor
        let cornealVector = astigmatismToVector(
            magnitude: keratometry.totalCornealAstigmatism,
            axis: keratometry.astigmatismAxis
        )

        // 2. Converter SIA para vetor
        let siaVector = astigmatismToVector(
            magnitude: incision.surgicallyInducedAstigmatism,
            axis: incision.axis
        )

        // 3. Somar vetores (astigmatismo corneano + SIA)
        let totalVector = addVectors(cornealVector, siaVector)

        // 4. Converter vetor resultante de volta para magnitude e eixo
        let (targetMagnitude, targetAxis) = vectorToAstigmatism(totalVector)

        // 5. Calcular astigmatismo residual
        let residualAstigmatism = abs(targetMagnitude - iol.cylinderPowerAtCornea)

        // 6. O eixo de implantação é perpendicular ou alinhado?
        // Para lentes tóricas, o eixo de marcação da LIO deve ser
        // alinhado com o eixo do meridiano mais curvo
        let implantationAxis = normalizeAxis(targetAxis)

        return ToricCalculationResult(
            implantationAxis: implantationAxis,
            targetAstigmatism: targetMagnitude,
            predictedResidualAstigmatism: residualAstigmatism,
            siaEffect: incision.surgicallyInducedAstigmatism,
            originalCornealAstigmatism: keratometry.totalCornealAstigmatism,
            selectedIOL: iol
        )
    }

    // MARK: - Cálculos Vetoriais

    /// Converte astigmatismo (magnitude + eixo) para representação vetorial
    /// Usando decomposição de Fourier
    private static func astigmatismToVector(magnitude: Double, axis: Double) -> (x: Double, y: Double) {
        // Duplicar o ângulo para representação vetorial (0-360)
        let theta = 2 * axis * .pi / 180

        let x = magnitude * cos(theta)
        let y = magnitude * sin(theta)

        return (x, y)
    }

    /// Converte vetor de volta para magnitude e eixo
    private static func vectorToAstigmatism(_ vector: (x: Double, y: Double)) -> (magnitude: Double, axis: Double) {
        let magnitude = sqrt(vector.x * vector.x + vector.y * vector.y)

        var theta = atan2(vector.y, vector.x)
        if theta < 0 {
            theta += 2 * .pi
        }

        // Dividir por 2 para voltar ao eixo (0-180)
        let axis = (theta * 180 / .pi) / 2

        return (magnitude, axis)
    }

    /// Soma dois vetores
    private static func addVectors(
        _ v1: (x: Double, y: Double),
        _ v2: (x: Double, y: Double)
    ) -> (x: Double, y: Double) {
        return (v1.x + v2.x, v1.y + v2.y)
    }

    /// Normaliza eixo para 0-180
    private static func normalizeAxis(_ axis: Double) -> Double {
        var normalized = axis.truncatingRemainder(dividingBy: 180)
        if normalized < 0 {
            normalized += 180
        }
        return normalized
    }

    // MARK: - Correção de Ciclotorção

    /// Corrige o eixo de implantação considerando a ciclotorção
    /// - Parameters:
    ///   - originalAxis: Eixo calculado originalmente
    ///   - cyclotorsion: Ciclotorção detectada (em graus, positivo = horário)
    /// - Returns: Eixo corrigido
    static func correctForCyclotorsion(
        originalAxis: Double,
        cyclotorsion: Double
    ) -> Double {
        // Subtrair a ciclotorção do eixo
        // Se o olho rotacionou X graus no sentido horário,
        // precisamos ajustar o eixo em -X graus
        let correctedAxis = originalAxis - cyclotorsion

        return normalizeAxis(correctedAxis)
    }

    // MARK: - Perda de Correção por Desalinhamento

    /// Calcula a perda de correção do astigmatismo por desalinhamento
    /// Cada grau de erro = ~3.3% de perda
    /// - Parameters:
    ///   - misalignment: Desalinhamento em graus
    ///   - iolCylinder: Cilindro da LIO
    /// - Returns: Astigmatismo residual devido ao desalinhamento
    static func calculateMisalignmentEffect(
        misalignment: Double,
        iolCylinder: Double
    ) -> MisalignmentEffect {
        // Fórmula: Residual = 2 * IOL_cylinder * sin(misalignment)
        let residualMagnitude = 2 * iolCylinder * sin(abs(misalignment) * .pi / 180)

        // Porcentagem de correção perdida
        let percentageLost = (1 - cos(2 * abs(misalignment) * .pi / 180)) * 100

        // Em 30° de erro, 100% da correção é perdida
        let isSignificant = abs(misalignment) >= 10

        return MisalignmentEffect(
            misalignmentDegrees: misalignment,
            residualAstigmatism: residualMagnitude,
            percentageCorrectionLost: percentageLost,
            isSignificant: isSignificant
        )
    }

    // MARK: - Recomendação de LIO

    /// Encontra as melhores opções de LIO para um dado astigmatismo
    static func recommendIOLs(
        targetAstigmatism: Double,
        manufacturer: IOLManufacturer? = nil,
        maxResidual: Double = 0.50
    ) -> [IOLRecommendation] {

        let candidates = manufacturer.map { IOLCatalog.models(for: $0) } ?? IOLCatalog.all

        return candidates
            .map { iol in
                let residual = abs(targetAstigmatism - iol.cylinderPowerAtCornea)
                return IOLRecommendation(
                    iol: iol,
                    predictedResidual: residual,
                    isOptimal: residual < maxResidual
                )
            }
            .filter { $0.predictedResidual < 1.0 } // Filtrar opções muito fora
            .sorted { $0.predictedResidual < $1.predictedResidual }
    }
}

// MARK: - Estruturas de Resultado

struct ToricCalculationResult {
    let implantationAxis: Double           // Eixo de implantação (0-180)
    let targetAstigmatism: Double          // Astigmatismo alvo a corrigir
    let predictedResidualAstigmatism: Double  // Astigmatismo residual previsto
    let siaEffect: Double                  // Efeito do SIA
    let originalCornealAstigmatism: Double // Astigmatismo corneano original
    let selectedIOL: ToricIOL              // LIO selecionada

    var correctionPercentage: Double {
        guard originalCornealAstigmatism > 0 else { return 0 }
        return ((originalCornealAstigmatism - predictedResidualAstigmatism) / originalCornealAstigmatism) * 100
    }
}

struct MisalignmentEffect {
    let misalignmentDegrees: Double
    let residualAstigmatism: Double
    let percentageCorrectionLost: Double
    let isSignificant: Bool

    var description: String {
        if isSignificant {
            return "Desalinhamento significativo: \(Int(percentageCorrectionLost))% da correção perdida"
        } else {
            return "Desalinhamento aceitável"
        }
    }
}

struct IOLRecommendation {
    let iol: ToricIOL
    let predictedResidual: Double
    let isOptimal: Bool

    var description: String {
        "\(iol.shortName) - Residual: \(String(format: "%.2f", predictedResidual))D"
    }
}
