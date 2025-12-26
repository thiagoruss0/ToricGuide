//
//  Patient.swift
//  ToricGuide
//
//  Modelo de dados do paciente
//

import Foundation

struct Patient: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var medicalRecordNumber: String // Prontuário
    var dateOfBirth: Date?
    var notes: String?

    // Data de criação
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String = "",
        medicalRecordNumber: String = "",
        dateOfBirth: Date? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.medicalRecordNumber = medicalRecordNumber
        self.dateOfBirth = dateOfBirth
        self.notes = notes
        self.createdAt = Date()
    }

    var displayName: String {
        name.isEmpty ? "Paciente sem nome" : name
    }
}

// MARK: - Olho a ser operado
enum Eye: String, Codable, CaseIterable {
    case right = "OD" // Oculus Dexter
    case left = "OE"  // Oculus Sinister

    var description: String {
        switch self {
        case .right: return "Direito"
        case .left: return "Esquerdo"
        }
    }

    var fullDescription: String {
        switch self {
        case .right: return "OD - Olho Direito"
        case .left: return "OE - Olho Esquerdo"
        }
    }
}
