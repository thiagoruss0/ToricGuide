//
//  ResultsView.swift
//  ToricGuide
//
//  Tela de resultado do cálculo do eixo de implantação
//  Mostra análise vetorial completa
//

import SwiftUI

struct ResultsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var patientStore: PatientStore

    @State private var showVectorDetails = false
    @State private var showingIOLComparison = false

    var surgicalCase: SurgicalCase? {
        appState.currentCase
    }

    var analysis: StoredToricAnalysis? {
        surgicalCase?.toricAnalysis
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header com informações do paciente
                patientHeader

                // Gráfico do eixo
                axisVisualization

                // Eixo de implantação destacado
                implantationAxisCard

                // Detalhes da análise vetorial
                if analysis != nil {
                    vectorAnalysisSection
                }

                // Detalhes da LIO
                iolDetails

                // Botões de ação
                actionButtons
            }
            .padding()
        }
        .navigationTitle("Resultado")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingIOLComparison) {
            if let keratometry = surgicalCase?.keratometry {
                IOLComparisonView(
                    targetAstigmatism: keratometry.totalCornealAstigmatism,
                    selectedManufacturer: surgicalCase?.selectedIOL?.manufacturer ?? .alcon
                )
            }
        }
    }

    // MARK: - Patient Header
    private var patientHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(appState.currentPatient?.name ?? "Paciente")
                    .font(.headline)

                HStack {
                    Text("Olho: \(surgicalCase?.eye.rawValue ?? "")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    if let date = surgicalCase?.surgeryDate {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(formatDate(date))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Correction type badge
            if let analysis = analysis {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(analysis.correctionType)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(correctionTypeColor.opacity(0.1))
                        .foregroundColor(correctionTypeColor)
                        .cornerRadius(6)

                    Text(String(format: "%.0f%% correção", analysis.correctionPercentage))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var correctionTypeColor: Color {
        guard let analysis = analysis else { return .blue }
        if analysis.isOvercorrection { return .orange }
        if analysis.isUndercorrection { return .blue }
        return .green
    }

    // MARK: - Axis Visualization
    private var axisVisualization: some View {
        VStack(spacing: 16) {
            ZStack {
                // Círculo do olho
                Circle()
                    .stroke(Color(.systemGray3), lineWidth: 2)
                    .frame(width: 200, height: 200)

                // Linhas de referência
                ForEach([0, 90, 180, 270], id: \.self) { angle in
                    AxisReferenceLine(angle: Double(angle))
                }

                // Labels dos ângulos
                AxisLabel(text: "0°", angle: 0, radius: 115)
                AxisLabel(text: "90°", angle: 90, radius: 115)
                AxisLabel(text: "180°", angle: 180, radius: 115)
                AxisLabel(text: "270°", angle: 270, radius: 115)

                // Linha do eixo calculado
                if let axis = surgicalCase?.calculatedAxis {
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: 180, height: 3)
                        .rotationEffect(.degrees(-axis + 90))

                    Circle()
                        .fill(Color.blue)
                        .frame(width: 12, height: 12)
                        .offset(x: 85 * cos((90 - axis) * .pi / 180),
                                y: -85 * sin((90 - axis) * .pi / 180))

                    Text("\(Int(axis))°")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .cornerRadius(6)
                        .offset(x: 70 * cos((90 - axis) * .pi / 180),
                                y: -70 * sin((90 - axis) * .pi / 180))
                }

                // Pupila central
                Circle()
                    .fill(Color.black)
                    .frame(width: 40, height: 40)

                Circle()
                    .fill(Color(.systemGray2))
                    .frame(width: 20, height: 20)
            }
            .frame(height: 250)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    // MARK: - Implantation Axis Card
    private var implantationAxisCard: some View {
        VStack(spacing: 8) {
            Text("EIXO DE IMPLANTAÇÃO")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            if let axis = surgicalCase?.calculatedAxis {
                Text("\(Int(axis))°")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.blue)
            } else {
                Text("-")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.secondary)
            }

            if let analysis = analysis {
                HStack(spacing: 16) {
                    VStack {
                        Text("Residual")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.2fD", analysis.residualMagnitude))
                            .font(.headline)
                            .foregroundColor(residualColor)
                    }

                    Divider().frame(height: 30)

                    VStack {
                        Text("Correção")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.0f%%", analysis.correctionPercentage))
                            .font(.headline)
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Vector Analysis Section
    private var vectorAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation {
                    showVectorDetails.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundColor(.purple)

                    Text("ANÁLISE VETORIAL")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    Spacer()

                    Image(systemName: showVectorDetails ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if showVectorDetails, let analysis = analysis {
                VStack(spacing: 0) {
                    VectorRow(
                        icon: "circle.fill",
                        iconColor: .blue,
                        title: "Astigmatismo Anterior",
                        value: analysis.anteriorFormatted
                    )

                    Divider()

                    VectorRow(
                        icon: "circle.fill",
                        iconColor: .purple,
                        title: "Astigmatismo Posterior",
                        value: analysis.posteriorFormatted,
                        subtitle: surgicalCase?.includesPosteriorAstigmatism == true ? "Baylor Nomogram" : "Não incluído"
                    )

                    Divider()

                    VectorRow(
                        icon: "equal.circle.fill",
                        iconColor: .green,
                        title: "TCA (Total Corneal Astig.)",
                        value: analysis.tcaFormatted,
                        isHighlighted: true
                    )

                    Divider()

                    VectorRow(
                        icon: "scissors",
                        iconColor: .orange,
                        title: "SIA (Surgically Induced)",
                        value: analysis.siaFormatted
                    )

                    Divider()

                    VectorRow(
                        icon: "arrow.right.circle.fill",
                        iconColor: .cyan,
                        title: "Pós-SIA (Target)",
                        value: analysis.postSIAFormatted,
                        isHighlighted: true
                    )

                    Divider()

                    VectorRow(
                        icon: "checkmark.circle.fill",
                        iconColor: residualColor,
                        title: "Residual Previsto",
                        value: analysis.residualFormatted,
                        isHighlighted: true
                    )
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
            }
        }
    }

    // MARK: - IOL Details
    private var iolDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("LIO SELECIONADA")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    showingIOLComparison = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left.arrow.right")
                        Text("Comparar")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }

            if let iol = surgicalCase?.selectedIOL {
                VStack(spacing: 0) {
                    ResultRow(
                        title: "Modelo",
                        value: iol.fullName
                    )

                    Divider()

                    ResultRow(
                        title: "Fabricante",
                        value: iol.manufacturer.rawValue
                    )

                    Divider()

                    ResultRow(
                        title: "Cilindro (plano IOL)",
                        value: String(format: "%.2f D", iol.cylinderPowerAtIOL)
                    )

                    Divider()

                    ResultRow(
                        title: "Cilindro (plano corneano)",
                        value: String(format: "%.2f D", iol.cylinderPowerAtCornea),
                        isHighlighted: true
                    )
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
            }
        }
    }

    private var residualColor: Color {
        guard let analysis = analysis else {
            guard let residual = surgicalCase?.residualAstigmatism else { return .primary }
            if residual < 0.25 { return .green }
            if residual < 0.50 { return .orange }
            return .red
        }
        if analysis.residualMagnitude < 0.25 { return .green }
        if analysis.residualMagnitude < 0.50 { return .orange }
        return .red
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                startSurgicalGuide()
            } label: {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("INICIAR GUIA CIRÚRGICO")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
            }

            Button {
                saveCase()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                    Text("SALVAR CASO")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray5))
                .foregroundColor(.primary)
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Helpers
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }

    private func startSurgicalGuide() {
        if var currentCase = appState.currentCase {
            currentCase.status = .inProgress
            appState.currentCase = currentCase
            patientStore.updateCase(currentCase)
        }
        appState.navigationPath.append(AppRoute.surgicalGuide)
    }

    private func saveCase() {
        if let currentCase = appState.currentCase {
            patientStore.updateCase(currentCase)
        }
        appState.navigationPath = NavigationPath()
    }
}

// MARK: - Vector Row
struct VectorRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    var subtitle: String? = nil
    var isHighlighted: Bool = false

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.system(size: 14))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(isHighlighted ? .primary : .secondary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Text(value)
                .font(isHighlighted ? .headline : .subheadline)
                .fontWeight(isHighlighted ? .semibold : .regular)
                .foregroundColor(isHighlighted ? .primary : .secondary)
        }
        .padding()
        .background(isHighlighted ? Color(.systemGray6) : Color.clear)
    }
}

// MARK: - Axis Reference Line
struct AxisReferenceLine: View {
    let angle: Double

    var body: some View {
        Rectangle()
            .fill(Color(.systemGray4))
            .frame(width: 200, height: 1)
            .rotationEffect(.degrees(-angle + 90))
    }
}

// MARK: - Axis Label
struct AxisLabel: View {
    let text: String
    let angle: Double
    let radius: CGFloat

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.secondary)
            .offset(
                x: radius * CGFloat(cos((90 - angle) * .pi / 180)),
                y: -radius * CGFloat(sin((90 - angle) * .pi / 180))
            )
    }
}

// MARK: - Result Row
struct ResultRow: View {
    let title: String
    let value: String
    var isHighlighted: Bool = false
    var valueColor: Color = .primary

    var body: some View {
        HStack {
            Text(title)
                .font(isHighlighted ? .subheadline : .subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(isHighlighted ? .headline : .subheadline)
                .fontWeight(isHighlighted ? .bold : .medium)
                .foregroundColor(isHighlighted ? .blue : valueColor)
        }
        .padding()
        .background(isHighlighted ? Color.blue.opacity(0.05) : Color.clear)
    }
}

#Preview {
    NavigationStack {
        ResultsView()
    }
    .environmentObject(AppState())
    .environmentObject(PatientStore.preview)
}
