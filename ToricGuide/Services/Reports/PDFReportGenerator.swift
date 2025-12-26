//
//  PDFReportGenerator.swift
//  ToricGuide
//
//  Gerador de relatórios PDF para casos cirúrgicos
//  Inclui análise vetorial, eixo de implantação e resultado
//

import Foundation
import UIKit
import PDFKit

class PDFReportGenerator {

    // MARK: - Page Settings
    struct PageSettings {
        static let pageWidth: CGFloat = 612 // Letter size
        static let pageHeight: CGFloat = 792
        static let margin: CGFloat = 50
        static let contentWidth: CGFloat = pageWidth - (margin * 2)
    }

    // MARK: - Colors
    struct ReportColors {
        static let primary = UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0)
        static let secondary = UIColor.darkGray
        static let accent = UIColor(red: 0.0, green: 0.6, blue: 0.4, alpha: 1.0)
        static let warning = UIColor.orange
    }

    // MARK: - Generate Report

    static func generateReport(
        patient: Patient,
        surgicalCase: SurgicalCase
    ) -> Data? {

        let pdfMetaData = [
            kCGPDFContextCreator: "ToricGuide",
            kCGPDFContextAuthor: "ToricGuide App",
            kCGPDFContextTitle: "Relatório Cirúrgico - \(patient.name)"
        ]

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageRect = CGRect(x: 0, y: 0, width: PageSettings.pageWidth, height: PageSettings.pageHeight)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { context in
            context.beginPage()

            var yOffset: CGFloat = PageSettings.margin

            // Header
            yOffset = drawHeader(at: yOffset, context: context)

            // Patient Info
            yOffset = drawPatientInfo(patient: patient, case_: surgicalCase, at: yOffset, context: context)

            // Keratometry
            if let keratometry = surgicalCase.keratometry {
                yOffset = drawKeratometry(keratometry: keratometry, at: yOffset, context: context)
            }

            // IOL Selected
            if let iol = surgicalCase.selectedIOL {
                yOffset = drawIOLInfo(iol: iol, at: yOffset, context: context)
            }

            // Vector Analysis
            if let analysis = surgicalCase.toricAnalysis {
                yOffset = drawVectorAnalysis(analysis: analysis, at: yOffset, context: context)
            }

            // Result
            yOffset = drawResult(case_: surgicalCase, at: yOffset, context: context)

            // Axis Diagram
            if let axis = surgicalCase.calculatedAxis {
                yOffset = drawAxisDiagram(targetAxis: axis, at: yOffset, context: context)
            }

            // Footer
            drawFooter(context: context)
        }

        return data
    }

    // MARK: - Header

    private static func drawHeader(at yOffset: CGFloat, context: UIGraphicsPDFRendererContext) -> CGFloat {
        var y = yOffset

        // Logo/Title
        let titleFont = UIFont.boldSystemFont(ofSize: 24)
        let title = "ToricGuide"
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: ReportColors.primary
        ]
        let titleRect = CGRect(x: PageSettings.margin, y: y, width: PageSettings.contentWidth, height: 30)
        title.draw(in: titleRect, withAttributes: titleAttributes)
        y += 35

        // Subtitle
        let subtitleFont = UIFont.systemFont(ofSize: 14)
        let subtitle = "Relatório de Implantação de LIO Tórica"
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: subtitleFont,
            .foregroundColor: ReportColors.secondary
        ]
        let subtitleRect = CGRect(x: PageSettings.margin, y: y, width: PageSettings.contentWidth, height: 20)
        subtitle.draw(in: subtitleRect, withAttributes: subtitleAttributes)
        y += 25

        // Separator line
        let linePath = UIBezierPath()
        linePath.move(to: CGPoint(x: PageSettings.margin, y: y))
        linePath.addLine(to: CGPoint(x: PageSettings.pageWidth - PageSettings.margin, y: y))
        ReportColors.primary.setStroke()
        linePath.lineWidth = 2
        linePath.stroke()
        y += 20

        return y
    }

    // MARK: - Patient Info

    private static func drawPatientInfo(
        patient: Patient,
        case_: SurgicalCase,
        at yOffset: CGFloat,
        context: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        var y = yOffset

        y = drawSectionTitle("INFORMAÇÕES DO PACIENTE", at: y)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"

        let infoItems = [
            ("Nome:", patient.name),
            ("Prontuário:", patient.medicalRecordNumber),
            ("Olho:", case_.eye.fullDescription),
            ("Data da Cirurgia:", dateFormatter.string(from: case_.surgeryDate)),
            ("Status:", case_.status.rawValue)
        ]

        for (label, value) in infoItems {
            y = drawLabelValue(label: label, value: value, at: y)
        }

        y += 15
        return y
    }

    // MARK: - Keratometry

    private static func drawKeratometry(
        keratometry: Keratometry,
        at yOffset: CGFloat,
        context: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        var y = yOffset

        y = drawSectionTitle("CERATOMETRIA", at: y)

        let k1 = String(format: "K1: %.2f D @ %.0f°", keratometry.k1Power, keratometry.k1Axis)
        let k2 = String(format: "K2: %.2f D @ %.0f°", keratometry.k2Power, keratometry.k2Axis)
        let astig = String(format: "Astigmatismo: %.2f D", keratometry.totalCornealAstigmatism)
        let type = "Tipo: \(keratometry.astigmatismType.rawValue)"

        y = drawInfoLine(k1, at: y)
        y = drawInfoLine(k2, at: y)
        y = drawInfoLine(astig, at: y, color: ReportColors.primary)
        y = drawInfoLine(type, at: y)

        y += 15
        return y
    }

    // MARK: - IOL Info

    private static func drawIOLInfo(
        iol: ToricIOL,
        at yOffset: CGFloat,
        context: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        var y = yOffset

        y = drawSectionTitle("LIO SELECIONADA", at: y)

        y = drawLabelValue(label: "Modelo:", value: iol.fullName, at: y)
        y = drawLabelValue(label: "Cilindro (plano IOL):", value: String(format: "%.2f D", iol.cylinderPowerAtIOL), at: y)
        y = drawLabelValue(label: "Cilindro (plano corneano):", value: String(format: "%.2f D", iol.cylinderPowerAtCornea), at: y)
        y = drawLabelValue(label: "Constante A:", value: String(format: "%.1f", iol.aConstant), at: y)

        y += 15
        return y
    }

    // MARK: - Vector Analysis

    private static func drawVectorAnalysis(
        analysis: StoredToricAnalysis,
        at yOffset: CGFloat,
        context: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        var y = yOffset

        y = drawSectionTitle("ANÁLISE VETORIAL", at: y)

        let items = [
            ("Astigmatismo Anterior:", analysis.anteriorFormatted),
            ("Astigmatismo Posterior:", analysis.posteriorFormatted),
            ("TCA (Total Corneal):", analysis.tcaFormatted),
            ("SIA:", analysis.siaFormatted),
            ("Pós-SIA (Target):", analysis.postSIAFormatted),
            ("Residual Previsto:", analysis.residualFormatted)
        ]

        for (label, value) in items {
            let highlight = label.contains("TCA") || label.contains("Target") || label.contains("Residual")
            y = drawLabelValue(label: label, value: value, at: y, highlight: highlight)
        }

        // Correction type
        y += 5
        let correctionColor = analysis.isOvercorrection ? ReportColors.warning : ReportColors.accent
        y = drawInfoLine("Tipo de Correção: \(analysis.correctionType)", at: y, color: correctionColor)
        y = drawInfoLine(String(format: "Correção: %.0f%%", analysis.correctionPercentage), at: y, color: ReportColors.accent)

        y += 15
        return y
    }

    // MARK: - Result

    private static func drawResult(
        case_: SurgicalCase,
        at yOffset: CGFloat,
        context: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        var y = yOffset

        y = drawSectionTitle("RESULTADO", at: y)

        // Main result box
        let boxRect = CGRect(
            x: PageSettings.margin,
            y: y,
            width: PageSettings.contentWidth,
            height: 80
        )

        // Background
        let boxPath = UIBezierPath(roundedRect: boxRect, cornerRadius: 8)
        UIColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0).setFill()
        boxPath.fill()

        // Border
        ReportColors.primary.setStroke()
        boxPath.lineWidth = 2
        boxPath.stroke()

        // Axis value
        if let axis = case_.calculatedAxis {
            let axisFont = UIFont.boldSystemFont(ofSize: 36)
            let axisText = "\(Int(axis))°"
            let axisAttributes: [NSAttributedString.Key: Any] = [
                .font: axisFont,
                .foregroundColor: ReportColors.primary
            ]

            let axisSize = axisText.size(withAttributes: axisAttributes)
            let axisRect = CGRect(
                x: boxRect.midX - axisSize.width / 2,
                y: boxRect.minY + 10,
                width: axisSize.width,
                height: axisSize.height
            )
            axisText.draw(in: axisRect, withAttributes: axisAttributes)

            // Label
            let labelFont = UIFont.systemFont(ofSize: 14)
            let labelText = "EIXO DE IMPLANTAÇÃO"
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: labelFont,
                .foregroundColor: ReportColors.secondary
            ]
            let labelSize = labelText.size(withAttributes: labelAttributes)
            let labelRect = CGRect(
                x: boxRect.midX - labelSize.width / 2,
                y: boxRect.maxY - 25,
                width: labelSize.width,
                height: labelSize.height
            )
            labelText.draw(in: labelRect, withAttributes: labelAttributes)
        }

        y = boxRect.maxY + 15

        // Final axis if completed
        if let finalAxis = case_.finalIOLAxis {
            y = drawLabelValue(
                label: "Eixo Final Implantado:",
                value: "\(Int(finalAxis))°",
                at: y,
                highlight: true
            )
        }

        // Cyclotorsion if available
        if let cyclotorsion = case_.intraopCyclotorsion {
            y = drawLabelValue(
                label: "Ciclotorção Detectada:",
                value: String(format: "%.1f°", cyclotorsion),
                at: y
            )
        }

        y += 15
        return y
    }

    // MARK: - Axis Diagram

    private static func drawAxisDiagram(
        targetAxis: Double,
        at yOffset: CGFloat,
        context: UIGraphicsPDFRendererContext
    ) -> CGFloat {
        var y = yOffset

        y = drawSectionTitle("DIAGRAMA DO EIXO", at: y)

        let centerX = PageSettings.pageWidth / 2
        let centerY = y + 80
        let radius: CGFloat = 60

        // Circle
        let circlePath = UIBezierPath(
            arcCenter: CGPoint(x: centerX, y: centerY),
            radius: radius,
            startAngle: 0,
            endAngle: CGFloat.pi * 2,
            clockwise: true
        )
        UIColor.lightGray.setStroke()
        circlePath.lineWidth = 1
        circlePath.stroke()

        // Reference lines (0°, 90°, 180°)
        for angle in [0.0, 90.0, 180.0] {
            let radians = (90 - angle) * .pi / 180
            let endX = centerX + (radius + 10) * CGFloat(cos(radians))
            let endY = centerY - (radius + 10) * CGFloat(sin(radians))

            let linePath = UIBezierPath()
            linePath.move(to: CGPoint(x: centerX, y: centerY))
            linePath.addLine(to: CGPoint(x: endX, y: endY))
            UIColor.lightGray.setStroke()
            linePath.lineWidth = 0.5
            linePath.stroke()

            // Label
            let labelFont = UIFont.systemFont(ofSize: 10)
            let labelText = "\(Int(angle))°"
            let labelX = centerX + (radius + 20) * CGFloat(cos(radians)) - 10
            let labelY = centerY - (radius + 20) * CGFloat(sin(radians)) - 6
            labelText.draw(
                at: CGPoint(x: labelX, y: labelY),
                withAttributes: [.font: labelFont, .foregroundColor: UIColor.gray]
            )
        }

        // Target axis line
        let targetRadians = (90 - targetAxis) * .pi / 180
        let targetEndX = centerX + radius * CGFloat(cos(targetRadians))
        let targetEndY = centerY - radius * CGFloat(sin(targetRadians))
        let targetStartX = centerX - radius * CGFloat(cos(targetRadians))
        let targetStartY = centerY + radius * CGFloat(sin(targetRadians))

        let targetPath = UIBezierPath()
        targetPath.move(to: CGPoint(x: targetStartX, y: targetStartY))
        targetPath.addLine(to: CGPoint(x: targetEndX, y: targetEndY))
        ReportColors.primary.setStroke()
        targetPath.lineWidth = 3
        targetPath.stroke()

        // Target label
        let targetLabelFont = UIFont.boldSystemFont(ofSize: 12)
        let targetLabelText = "\(Int(targetAxis))°"
        let targetLabelX = centerX + (radius + 25) * CGFloat(cos(targetRadians)) - 15
        let targetLabelY = centerY - (radius + 25) * CGFloat(sin(targetRadians)) - 8
        targetLabelText.draw(
            at: CGPoint(x: targetLabelX, y: targetLabelY),
            withAttributes: [.font: targetLabelFont, .foregroundColor: ReportColors.primary]
        )

        // Center dot
        let dotPath = UIBezierPath(
            arcCenter: CGPoint(x: centerX, y: centerY),
            radius: 4,
            startAngle: 0,
            endAngle: CGFloat.pi * 2,
            clockwise: true
        )
        UIColor.black.setFill()
        dotPath.fill()

        return centerY + radius + 40
    }

    // MARK: - Footer

    private static func drawFooter(context: UIGraphicsPDFRendererContext) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy HH:mm"
        let dateText = "Gerado em: \(dateFormatter.string(from: Date()))"

        let font = UIFont.systemFont(ofSize: 10)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.gray
        ]

        let textSize = dateText.size(withAttributes: attributes)
        let x = PageSettings.pageWidth - PageSettings.margin - textSize.width
        let y = PageSettings.pageHeight - PageSettings.margin

        dateText.draw(at: CGPoint(x: x, y: y), withAttributes: attributes)

        // App version
        let versionText = "ToricGuide v1.0"
        let versionSize = versionText.size(withAttributes: attributes)
        versionText.draw(at: CGPoint(x: PageSettings.margin, y: y), withAttributes: attributes)
    }

    // MARK: - Helper Drawing Methods

    private static func drawSectionTitle(_ title: String, at yOffset: CGFloat) -> CGFloat {
        let font = UIFont.boldSystemFont(ofSize: 14)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: ReportColors.primary
        ]

        let rect = CGRect(x: PageSettings.margin, y: yOffset, width: PageSettings.contentWidth, height: 20)
        title.draw(in: rect, withAttributes: attributes)

        // Underline
        let linePath = UIBezierPath()
        linePath.move(to: CGPoint(x: PageSettings.margin, y: yOffset + 18))
        linePath.addLine(to: CGPoint(x: PageSettings.margin + 150, y: yOffset + 18))
        ReportColors.primary.setStroke()
        linePath.lineWidth = 1
        linePath.stroke()

        return yOffset + 25
    }

    private static func drawLabelValue(
        label: String,
        value: String,
        at yOffset: CGFloat,
        highlight: Bool = false
    ) -> CGFloat {
        let labelFont = UIFont.systemFont(ofSize: 11)
        let valueFont = highlight ? UIFont.boldSystemFont(ofSize: 11) : UIFont.systemFont(ofSize: 11)

        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: ReportColors.secondary
        ]

        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: valueFont,
            .foregroundColor: highlight ? ReportColors.primary : UIColor.black
        ]

        let labelRect = CGRect(x: PageSettings.margin, y: yOffset, width: 180, height: 16)
        label.draw(in: labelRect, withAttributes: labelAttributes)

        let valueRect = CGRect(x: PageSettings.margin + 180, y: yOffset, width: PageSettings.contentWidth - 180, height: 16)
        value.draw(in: valueRect, withAttributes: valueAttributes)

        return yOffset + 18
    }

    private static func drawInfoLine(_ text: String, at yOffset: CGFloat, color: UIColor = .black) -> CGFloat {
        let font = UIFont.systemFont(ofSize: 11)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]

        let rect = CGRect(x: PageSettings.margin + 10, y: yOffset, width: PageSettings.contentWidth - 10, height: 16)
        text.draw(in: rect, withAttributes: attributes)

        return yOffset + 18
    }

    // MARK: - Save Report

    static func saveReport(
        _ data: Data,
        patient: Patient,
        case_: SurgicalCase
    ) -> URL? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateString = dateFormatter.string(from: case_.surgeryDate)

        let sanitizedName = patient.name.replacingOccurrences(of: " ", with: "_")
        let filename = "ToricGuide_\(sanitizedName)_\(case_.eye.rawValue)_\(dateString).pdf"

        do {
            return try DataPersistenceService.shared.saveReport(data, named: filename)
        } catch {
            print("[PDFReportGenerator] Error saving report: \(error)")
            return nil
        }
    }
}
