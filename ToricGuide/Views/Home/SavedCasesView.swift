//
//  SavedCasesView.swift
//  ToricGuide
//
//  Lista de casos salvos
//

import SwiftUI

struct SavedCasesView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var patientStore: PatientStore
    @State private var searchText = ""
    @State private var filterStatus: CaseStatus?

    var filteredCases: [SurgicalCase] {
        var result = patientStore.cases

        // Filtro por texto
        if !searchText.isEmpty {
            result = result.filter { surgicalCase in
                if let patient = patientStore.getPatient(by: surgicalCase.patientId) {
                    return patient.name.localizedCaseInsensitiveContains(searchText) ||
                           patient.medicalRecordNumber.contains(searchText)
                }
                return false
            }
        }

        // Filtro por status
        if let status = filterStatus {
            result = result.filter { $0.status == status }
        }

        return result.sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Barra de busca
            searchBar

            // Filtros
            filterBar

            // Lista
            if filteredCases.isEmpty {
                emptyState
            } else {
                casesList
            }
        }
        .navigationTitle("Casos Salvos")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Barra de Busca
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Buscar por nome ou prontuário", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding()
    }

    // MARK: - Filtros
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "Todos",
                    isSelected: filterStatus == nil
                ) {
                    filterStatus = nil
                }

                ForEach([CaseStatus.calculated, .inProgress, .completed], id: \.self) { status in
                    FilterChip(
                        title: status.rawValue,
                        isSelected: filterStatus == status
                    ) {
                        filterStatus = status
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Lista de Casos
    private var casesList: some View {
        List {
            ForEach(filteredCases) { surgicalCase in
                CaseRowView(surgicalCase: surgicalCase)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectCase(surgicalCase)
                    }
            }
            .onDelete(perform: deleteCase)
        }
        .listStyle(PlainListStyle())
    }

    // MARK: - Estado Vazio
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("Nenhum caso encontrado")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Casos cirúrgicos aparecerão aqui")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()
        }
    }

    // MARK: - Ações
    private func selectCase(_ surgicalCase: SurgicalCase) {
        appState.currentCase = surgicalCase
        if let patient = patientStore.getPatient(by: surgicalCase.patientId) {
            appState.currentPatient = patient
        }

        // Navegar para a tela apropriada baseado no status
        switch surgicalCase.status {
        case .draft, .referenceCapured:
            appState.navigationPath.append(AppRoute.biometricData)
        case .calculated:
            appState.navigationPath.append(AppRoute.results)
        case .inProgress, .completed:
            appState.navigationPath.append(AppRoute.surgicalGuide)
        }
    }

    private func deleteCase(at offsets: IndexSet) {
        for index in offsets {
            let surgicalCase = filteredCases[index]
            patientStore.deleteCase(surgicalCase)
        }
    }
}

// MARK: - Linha do Caso
struct CaseRowView: View {
    let surgicalCase: SurgicalCase
    @EnvironmentObject var patientStore: PatientStore

    var patient: Patient? {
        patientStore.getPatient(by: surgicalCase.patientId)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Ícone de status
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: surgicalCase.status.icon)
                    .foregroundColor(statusColor)
            }

            // Informações
            VStack(alignment: .leading, spacing: 4) {
                Text(patient?.name ?? "Paciente")
                    .font(.system(size: 16, weight: .medium))

                HStack(spacing: 8) {
                    Text(surgicalCase.eye.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)

                    if let axis = surgicalCase.calculatedAxis {
                        Text("Eixo: \(Int(axis))°")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text(formatDate(surgicalCase.surgeryDate))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Status
            Text(surgicalCase.status.rawValue)
                .font(.caption)
                .foregroundColor(statusColor)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }

    private var statusColor: Color {
        switch surgicalCase.status {
        case .draft: return .gray
        case .referenceCapured: return .orange
        case .calculated: return .blue
        case .inProgress: return .purple
        case .completed: return .green
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yy"
        return formatter.string(from: date)
    }
}

// MARK: - Chip de Filtro
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

#Preview {
    NavigationStack {
        SavedCasesView()
    }
    .environmentObject(AppState())
    .environmentObject(PatientStore.preview)
}
