//
//  IOLComparisonView.swift
//  ToricGuide
//
//  Tela de comparação de LIOs tóricas
//  Mostra recomendações baseadas no astigmatismo alvo
//

import SwiftUI

struct IOLComparisonView: View {
    @Environment(\.dismiss) private var dismiss

    let targetAstigmatism: Double
    let selectedManufacturer: IOLManufacturer

    @State private var filterManufacturer: IOLManufacturer?
    @State private var showAllManufacturers = false
    @State private var selectedIOL: ToricIOL?

    var recommendations: [IOLRecommendation] {
        ToricCalculator.recommendIOLs(
            targetAstigmatism: targetAstigmatism,
            manufacturer: showAllManufacturers ? nil : filterManufacturer,
            preferUndercorrection: true,
            maxResidual: 1.5
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header com target
                targetHeader

                // Filtro de fabricante
                manufacturerFilter

                // Lista de recomendações
                recommendationsList
            }
            .navigationTitle("Comparar LIOs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fechar") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            filterManufacturer = selectedManufacturer
        }
    }

    // MARK: - Target Header
    private var targetHeader: some View {
        VStack(spacing: 8) {
            Text("ASTIGMATISMO ALVO")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(String(format: "%.2f", targetAstigmatism))
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.blue)

                Text("D")
                    .font(.title2)
                    .foregroundColor(.blue)
            }

            Text("No plano corneano")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.blue.opacity(0.05))
    }

    // MARK: - Manufacturer Filter
    private var manufacturerFilter: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Filtrar por fabricante")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Toggle("Todos", isOn: $showAllManufacturers)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .scaleEffect(0.8)

                Text("Todos")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !showAllManufacturers {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(IOLManufacturer.allCases, id: \.self) { manufacturer in
                            ManufacturerChip(
                                manufacturer: manufacturer,
                                isSelected: filterManufacturer == manufacturer
                            ) {
                                filterManufacturer = manufacturer
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }

    // MARK: - Recommendations List
    private var recommendationsList: some View {
        ScrollView {
            if recommendations.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(Array(recommendations.enumerated()), id: \.element.iol.id) { index, recommendation in
                        IOLRecommendationCard(
                            recommendation: recommendation,
                            targetAstigmatism: targetAstigmatism,
                            rank: index + 1,
                            isSelected: selectedIOL?.id == recommendation.iol.id
                        ) {
                            withAnimation {
                                selectedIOL = recommendation.iol
                            }
                        }
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "eyeglasses")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text("Nenhuma LIO encontrada")
                .font(.headline)

            Text("Tente alterar o filtro de fabricante ou\no astigmatismo está fora da faixa disponível")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Manufacturer Chip
struct ManufacturerChip: View {
    let manufacturer: IOLManufacturer
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(manufacturer.rawValue)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.blue : Color(.systemGray3), lineWidth: 1)
                )
        }
    }
}

// MARK: - IOL Recommendation Card
struct IOLRecommendationCard: View {
    let recommendation: IOLRecommendation
    let targetAstigmatism: Double
    let rank: Int
    let isSelected: Bool
    let action: () -> Void

    private var iol: ToricIOL { recommendation.iol }

    private var residualColor: Color {
        if recommendation.predictedResidual < 0.25 {
            return .green
        } else if recommendation.predictedResidual < 0.50 {
            return .orange
        } else {
            return .red
        }
    }

    private var correctionBadgeColor: Color {
        recommendation.isOvercorrection ? .orange : .blue
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Rank badge
                ZStack {
                    Circle()
                        .fill(rank == 1 ? Color.green : Color(.systemGray4))
                        .frame(width: 32, height: 32)

                    if rank == 1 {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text("\(rank)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }

                // IOL info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(iol.fullName)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Spacer()

                        // Correction type badge
                        Text(recommendation.isOvercorrection ? "Hiper" : "Sub")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(correctionBadgeColor.opacity(0.15))
                            .foregroundColor(correctionBadgeColor)
                            .cornerRadius(4)
                    }

                    HStack(spacing: 16) {
                        // Cylinder at cornea
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Cilindro")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.2fD", iol.cylinderPowerAtCornea))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }

                        // Difference
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Diferença")
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            let diff = iol.cylinderPowerAtCornea - targetAstigmatism
                            Text(String(format: "%+.2fD", diff))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(diff > 0 ? .orange : .blue)
                        }

                        Spacer()

                        // Residual
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Residual")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.2fD", recommendation.predictedResidual))
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(residualColor)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview
#Preview {
    IOLComparisonView(
        targetAstigmatism: 1.75,
        selectedManufacturer: .alcon
    )
}
