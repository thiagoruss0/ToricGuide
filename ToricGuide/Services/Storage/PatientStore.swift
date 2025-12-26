//
//  PatientStore.swift
//  ToricGuide
//
//  Serviço de persistência de dados
//

import Foundation
import SwiftUI

class PatientStore: ObservableObject {
    @Published var patients: [Patient] = []
    @Published var cases: [SurgicalCase] = []

    private let patientsKey = "toricguide_patients"
    private let casesKey = "toricguide_cases"

    init() {
        loadData()
    }

    // MARK: - Carregar dados
    private func loadData() {
        if let patientsData = UserDefaults.standard.data(forKey: patientsKey),
           let decoded = try? JSONDecoder().decode([Patient].self, from: patientsData) {
            patients = decoded
        }

        if let casesData = UserDefaults.standard.data(forKey: casesKey),
           let decoded = try? JSONDecoder().decode([SurgicalCase].self, from: casesData) {
            cases = decoded
        }
    }

    // MARK: - Salvar dados
    private func savePatients() {
        if let encoded = try? JSONEncoder().encode(patients) {
            UserDefaults.standard.set(encoded, forKey: patientsKey)
        }
    }

    private func saveCases() {
        if let encoded = try? JSONEncoder().encode(cases) {
            UserDefaults.standard.set(encoded, forKey: casesKey)
        }
    }

    // MARK: - CRUD Pacientes
    func addPatient(_ patient: Patient) {
        patients.append(patient)
        savePatients()
    }

    func updatePatient(_ patient: Patient) {
        if let index = patients.firstIndex(where: { $0.id == patient.id }) {
            patients[index] = patient
            savePatients()
        }
    }

    func deletePatient(_ patient: Patient) {
        patients.removeAll { $0.id == patient.id }
        // Também remove todos os casos do paciente
        cases.removeAll { $0.patientId == patient.id }
        savePatients()
        saveCases()
    }

    func getPatient(by id: UUID) -> Patient? {
        patients.first { $0.id == id }
    }

    // MARK: - CRUD Casos
    func addCase(_ surgicalCase: SurgicalCase) {
        cases.append(surgicalCase)
        saveCases()
    }

    func updateCase(_ surgicalCase: SurgicalCase) {
        if let index = cases.firstIndex(where: { $0.id == surgicalCase.id }) {
            var updated = surgicalCase
            updated.updateTimestamp()
            cases[index] = updated
            saveCases()
        }
    }

    func deleteCase(_ surgicalCase: SurgicalCase) {
        cases.removeAll { $0.id == surgicalCase.id }
        saveCases()
    }

    func getCase(by id: UUID) -> SurgicalCase? {
        cases.first { $0.id == id }
    }

    func getCases(for patientId: UUID) -> [SurgicalCase] {
        cases.filter { $0.patientId == patientId }
            .sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Casos recentes
    var recentCases: [SurgicalCase] {
        cases.sorted { $0.updatedAt > $1.updatedAt }
            .prefix(10)
            .map { $0 }
    }

    // MARK: - Casos pendentes (para cirurgia)
    var pendingCases: [SurgicalCase] {
        cases.filter { $0.status == .calculated }
            .sorted { $0.surgeryDate < $1.surgeryDate }
    }

    // MARK: - Estatísticas
    var totalPatients: Int { patients.count }
    var totalCases: Int { cases.count }
    var completedCases: Int { cases.filter { $0.status == .completed }.count }
}

// MARK: - Preview Helper
extension PatientStore {
    static var preview: PatientStore {
        let store = PatientStore()

        // Adicionar dados de exemplo
        let patient1 = Patient(name: "João da Silva", medicalRecordNumber: "12345")
        let patient2 = Patient(name: "Maria Santos", medicalRecordNumber: "67890")

        store.patients = [patient1, patient2]

        var case1 = SurgicalCase(patientId: patient1.id, eye: .right)
        case1.status = .calculated
        case1.calculatedAxis = 73
        case1.keratometry = Keratometry(k1Power: 43.50, k1Axis: 180, k2Power: 45.25, k2Axis: 90)

        var case2 = SurgicalCase(patientId: patient2.id, eye: .left)
        case2.status = .completed
        case2.calculatedAxis = 45

        store.cases = [case1, case2]

        return store
    }
}
