//
//  DataPersistenceService.swift
//  ToricGuide
//
//  Serviço de persistência robusto para dados médicos
//  Separa metadados (JSON) de arquivos grandes (imagens)
//

import Foundation
import UIKit

class DataPersistenceService {

    // MARK: - Singleton
    static let shared = DataPersistenceService()

    // MARK: - Directories
    private let fileManager = FileManager.default

    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var dataDirectory: URL {
        documentsDirectory.appendingPathComponent("ToricGuideData", isDirectory: true)
    }

    private var imagesDirectory: URL {
        dataDirectory.appendingPathComponent("Images", isDirectory: true)
    }

    private var reportsDirectory: URL {
        dataDirectory.appendingPathComponent("Reports", isDirectory: true)
    }

    private var backupsDirectory: URL {
        dataDirectory.appendingPathComponent("Backups", isDirectory: true)
    }

    // MARK: - File Names
    private let patientsFileName = "patients.json"
    private let casesFileName = "cases.json"
    private let settingsFileName = "settings.json"

    // MARK: - Initialization
    private init() {
        createDirectoriesIfNeeded()
    }

    private func createDirectoriesIfNeeded() {
        let directories = [dataDirectory, imagesDirectory, reportsDirectory, backupsDirectory]

        for directory in directories {
            if !fileManager.fileExists(atPath: directory.path) {
                try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            }
        }
    }

    // MARK: - Save/Load Patients

    func savePatients(_ patients: [Patient]) throws {
        let url = dataDirectory.appendingPathComponent(patientsFileName)
        let data = try JSONEncoder().encode(patients)
        try data.write(to: url)
    }

    func loadPatients() throws -> [Patient] {
        let url = dataDirectory.appendingPathComponent(patientsFileName)

        guard fileManager.fileExists(atPath: url.path) else {
            return []
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Patient].self, from: data)
    }

    // MARK: - Save/Load Cases

    func saveCases(_ cases: [SurgicalCase]) throws {
        // Separar imagens dos casos antes de salvar
        var casesWithoutImages: [CaseMetadata] = []

        for surgicalCase in cases {
            // Salvar imagem separadamente
            if let imageData = surgicalCase.referenceImageData {
                try saveImage(imageData, forCaseId: surgicalCase.id)
            }

            // Criar metadata sem imagem
            casesWithoutImages.append(CaseMetadata(from: surgicalCase))
        }

        let url = dataDirectory.appendingPathComponent(casesFileName)
        let data = try JSONEncoder().encode(casesWithoutImages)
        try data.write(to: url)
    }

    func loadCases() throws -> [SurgicalCase] {
        let url = dataDirectory.appendingPathComponent(casesFileName)

        guard fileManager.fileExists(atPath: url.path) else {
            return []
        }

        let data = try Data(contentsOf: url)
        let metadata = try JSONDecoder().decode([CaseMetadata].self, from: data)

        // Reconstruir casos com imagens
        return metadata.map { meta in
            var surgicalCase = meta.toSurgicalCase()

            // Carregar imagem se existir
            if let imageData = loadImage(forCaseId: surgicalCase.id) {
                surgicalCase.referenceImageData = imageData
            }

            return surgicalCase
        }
    }

    // MARK: - Image Storage

    func saveImage(_ data: Data, forCaseId id: UUID) throws {
        let url = imagesDirectory.appendingPathComponent("\(id.uuidString).jpg")
        try data.write(to: url)
    }

    func loadImage(forCaseId id: UUID) -> Data? {
        let url = imagesDirectory.appendingPathComponent("\(id.uuidString).jpg")
        return try? Data(contentsOf: url)
    }

    func deleteImage(forCaseId id: UUID) {
        let url = imagesDirectory.appendingPathComponent("\(id.uuidString).jpg")
        try? fileManager.removeItem(at: url)
    }

    // MARK: - Backup

    func createBackup() throws -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let backupName = "ToricGuide_Backup_\(timestamp).zip"
        let backupURL = backupsDirectory.appendingPathComponent(backupName)

        // Criar arquivo zip com todos os dados
        // Por simplicidade, vamos copiar os arquivos JSON
        let patientsURL = dataDirectory.appendingPathComponent(patientsFileName)
        let casesURL = dataDirectory.appendingPathComponent(casesFileName)

        let backupDir = backupsDirectory.appendingPathComponent(timestamp, isDirectory: true)
        try fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)

        if fileManager.fileExists(atPath: patientsURL.path) {
            try fileManager.copyItem(at: patientsURL, to: backupDir.appendingPathComponent(patientsFileName))
        }
        if fileManager.fileExists(atPath: casesURL.path) {
            try fileManager.copyItem(at: casesURL, to: backupDir.appendingPathComponent(casesFileName))
        }

        // Copiar imagens
        let imagesBackupDir = backupDir.appendingPathComponent("Images", isDirectory: true)
        try? fileManager.copyItem(at: imagesDirectory, to: imagesBackupDir)

        return backupDir
    }

    func listBackups() -> [URL] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: backupsDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return []
        }

        return contents.sorted { url1, url2 in
            let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            return date1 > date2
        }
    }

    // MARK: - Reports Directory

    func saveReport(_ data: Data, named filename: String) throws -> URL {
        let url = reportsDirectory.appendingPathComponent(filename)
        try data.write(to: url)
        return url
    }

    func getReportsDirectory() -> URL {
        reportsDirectory
    }

    // MARK: - Storage Info

    func getStorageInfo() -> StorageInfo {
        var totalSize: Int64 = 0
        var imageCount = 0
        var reportCount = 0

        // Calcular tamanho total
        if let enumerator = fileManager.enumerator(at: dataDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(fileSize)
                }
            }
        }

        // Contar imagens
        if let images = try? fileManager.contentsOfDirectory(atPath: imagesDirectory.path) {
            imageCount = images.count
        }

        // Contar relatórios
        if let reports = try? fileManager.contentsOfDirectory(atPath: reportsDirectory.path) {
            reportCount = reports.count
        }

        return StorageInfo(
            totalSizeBytes: totalSize,
            imageCount: imageCount,
            reportCount: reportCount
        )
    }

    // MARK: - Clear Data

    func clearAllData() throws {
        try fileManager.removeItem(at: dataDirectory)
        createDirectoriesIfNeeded()
    }

    func clearImages() throws {
        try fileManager.removeItem(at: imagesDirectory)
        try fileManager.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
    }

    func clearReports() throws {
        try fileManager.removeItem(at: reportsDirectory)
        try fileManager.createDirectory(at: reportsDirectory, withIntermediateDirectories: true)
    }
}

// MARK: - Case Metadata (sem imagem)

struct CaseMetadata: Codable {
    let id: UUID
    let patientId: UUID
    var eye: Eye
    var surgeryDate: Date
    var referenceImageTimestamp: Date?
    var referenceLandmarks: EyeLandmarks?
    var keratometry: Keratometry?
    var incision: IncisionData?
    var selectedIOL: ToricIOL?
    var calculatedAxis: Double?
    var residualAstigmatism: Double?
    var toricAnalysis: StoredToricAnalysis?
    var includesPosteriorAstigmatism: Bool
    var intraopCyclotorsion: Double?
    var finalIOLAxis: Double?
    var status: CaseStatus
    let createdAt: Date
    var updatedAt: Date
    var completedAt: Date?

    init(from case_: SurgicalCase) {
        self.id = case_.id
        self.patientId = case_.patientId
        self.eye = case_.eye
        self.surgeryDate = case_.surgeryDate
        self.referenceImageTimestamp = case_.referenceImageTimestamp
        self.referenceLandmarks = case_.referenceLandmarks
        self.keratometry = case_.keratometry
        self.incision = case_.incision
        self.selectedIOL = case_.selectedIOL
        self.calculatedAxis = case_.calculatedAxis
        self.residualAstigmatism = case_.residualAstigmatism
        self.toricAnalysis = case_.toricAnalysis
        self.includesPosteriorAstigmatism = case_.includesPosteriorAstigmatism
        self.intraopCyclotorsion = case_.intraopCyclotorsion
        self.finalIOLAxis = case_.finalIOLAxis
        self.status = case_.status
        self.createdAt = case_.createdAt
        self.updatedAt = case_.updatedAt
        self.completedAt = case_.completedAt
    }

    func toSurgicalCase() -> SurgicalCase {
        var surgicalCase = SurgicalCase(id: id, patientId: patientId, eye: eye, surgeryDate: surgeryDate)
        surgicalCase.referenceImageTimestamp = referenceImageTimestamp
        surgicalCase.referenceLandmarks = referenceLandmarks
        surgicalCase.keratometry = keratometry
        surgicalCase.incision = incision
        surgicalCase.selectedIOL = selectedIOL
        surgicalCase.calculatedAxis = calculatedAxis
        surgicalCase.residualAstigmatism = residualAstigmatism
        surgicalCase.toricAnalysis = toricAnalysis
        surgicalCase.includesPosteriorAstigmatism = includesPosteriorAstigmatism
        surgicalCase.intraopCyclotorsion = intraopCyclotorsion
        surgicalCase.finalIOLAxis = finalIOLAxis
        surgicalCase.status = status
        surgicalCase.completedAt = completedAt
        return surgicalCase
    }
}

// MARK: - Storage Info

struct StorageInfo {
    let totalSizeBytes: Int64
    let imageCount: Int
    let reportCount: Int

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSizeBytes)
    }
}
