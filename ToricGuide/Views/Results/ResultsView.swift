//
//  ResultsView.swift
//  ToricGuide
//
//  Tela de resultado do cálculo do eixo de implantação
//

import SwiftUI

struct ResultsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var patientStore: PatientStore

    var surgicalCase: SurgicalCase? {
        appState.currentCase
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header com informações do paciente
                patientHeader

                // Gráfico do eixo
                axisVisualization

                // Detalhes do resultado
                resultDetails

                // Botões de ação
                actionButtons
            }
            .padding()
        }
        .navigationTitle("Resultado")
        .navigationBarTitleDisplayMode(.inline)
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

            // Status badge
            Text(surgicalCase?.status.rawValue ?? "")
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Axis Visualization
    private var axisVisualization: some View {
        VStack(spacing: 16) {
            // Gráfico circular do olho
            ZStack {
                // Círculo do olho
                Circle()
                    .stroke(Color(.systemGray3), lineWidth: 2)
                    .frame(width: 200, height: 200)

                // Linhas de referência (0, 90, 180, 270)
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
                    // Linha principal do eixo
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: 180, height: 3)
                        .rotationEffect(.degrees(-axis + 90))

                    // Indicador de direção
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 12, height: 12)
                        .offset(x: 85 * cos((90 - axis) * .pi / 180),
                                y: -85 * sin((90 - axis) * .pi / 180))

                    // Label do eixo
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

    // MARK: - Result Details
    private var resultDetails: some View {
        VStack(spacing: 0) {
            // Eixo de implantação
            ResultRow(
                title: "EIXO DE IMPLANTAÇÃO",
                value: surgicalCase?.calculatedAxis != nil ? "\(Int(surgicalCase!.calculatedAxis!))°" : "-",
                isHighlighted: true
            )

            Divider()

            // LIO Recomendada
            if let iol = surgicalCase?.selectedIOL {
                ResultRow(
                    title: "LIO Recomendada",
                    value: iol.fullName
                )

                Divider()

                ResultRow(
                    title: "Cilindro no plano da LIO",
                    value: String(format: "%.2f D", iol.cylinderPowerAtIOL)
                )

                Divider()

                ResultRow(
                    title: "Cilindro no plano corneano",
                    value: String(format: "%.2f D", iol.cylinderPowerAtCornea)
                )
            }

            Divider()

            // Astigmatismo residual
            ResultRow(
                title: "Astigmatismo residual previsto",
                value: surgicalCase?.residualAstigmatism != nil ?
                    String(format: "%.2f D", surgicalCase!.residualAstigmatism!) : "-",
                valueColor: residualColor
            )
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private var residualColor: Color {
        guard let residual = surgicalCase?.residualAstigmatism else { return .primary }
        if residual < 0.25 { return .green }
        if residual < 0.50 { return .orange }
        return .red
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Iniciar guia cirúrgico
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

            // Salvar caso
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
        // Voltar para home
        appState.navigationPath = NavigationPath()
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
                .font(isHighlighted ? .title2 : .subheadline)
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
