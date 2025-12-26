//
//  SettingsView.swift
//  ToricGuide
//
//  Configurações do aplicativo
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("surgeonName") private var surgeonName = ""
    @AppStorage("clinicName") private var clinicName = ""
    @AppStorage("defaultManufacturer") private var defaultManufacturer = "Alcon"
    @AppStorage("defaultIncisionSize") private var defaultIncisionSize = 2.4
    @AppStorage("autoSaveEnabled") private var autoSaveEnabled = true
    @AppStorage("hapticFeedbackEnabled") private var hapticFeedbackEnabled = true

    var body: some View {
        Form {
            // MARK: - Identificação
            Section {
                TextField("Nome do Cirurgião", text: $surgeonName)
                TextField("Nome da Clínica/Hospital", text: $clinicName)
            } header: {
                Label("Identificação", systemImage: "person.crop.circle")
            }

            // MARK: - Preferências de LIO
            Section {
                Picker("Fabricante Padrão", selection: $defaultManufacturer) {
                    ForEach(IOLManufacturer.allCases, id: \.rawValue) { manufacturer in
                        Text(manufacturer.rawValue).tag(manufacturer.rawValue)
                    }
                }

                HStack {
                    Text("Incisão Padrão")
                    Spacer()
                    Picker("", selection: $defaultIncisionSize) {
                        ForEach(IncisionSizes.common, id: \.self) { size in
                            Text(String(format: "%.1f mm", size)).tag(size)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            } header: {
                Label("Preferências de LIO", systemImage: "eyeglasses")
            }

            // MARK: - MicroRec
            Section {
                HStack {
                    Text("Status")
                    Spacer()
                    if appState.microRecCalibrated {
                        Label("Calibrado", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Label("Não calibrado", systemImage: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                    }
                }

                NavigationLink {
                    MicroRecCalibrationView()
                } label: {
                    Label("Calibrar MicroRec", systemImage: "camera.metering.matrix")
                }

                HStack {
                    Text("Zoom")
                    Spacer()
                    Stepper(
                        String(format: "%.1fx", appState.cameraZoomLevel),
                        value: $appState.cameraZoomLevel,
                        in: 1.0...5.0,
                        step: 0.5
                    )
                }
            } header: {
                Label("MicroRec / Câmera", systemImage: "camera")
            } footer: {
                Text("Configure o adaptador MicroRec para uso com o microscópio Zeiss Opmi Lumera I")
            }

            // MARK: - Comportamento
            Section {
                Toggle("Salvar automaticamente", isOn: $autoSaveEnabled)
                Toggle("Feedback háptico", isOn: $hapticFeedbackEnabled)
            } header: {
                Label("Comportamento", systemImage: "gearshape.2")
            }

            // MARK: - Dados
            Section {
                NavigationLink {
                    DataManagementView()
                } label: {
                    Label("Gerenciar Dados", systemImage: "externaldrive")
                }

                NavigationLink {
                    AboutView()
                } label: {
                    Label("Sobre o ToricGuide", systemImage: "info.circle")
                }
            } header: {
                Label("Dados e Informações", systemImage: "folder")
            }

            // MARK: - Versão
            Section {
                HStack {
                    Text("Versão")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Configurações")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Calibração MicroRec Avançada
struct MicroRecCalibrationView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var calibrationService = MicroscopeCalibrationService.shared
    @State private var selectedTab = 0
    @State private var step = 0
    @State private var rotationOffset: Double = 0
    @State private var showingResetAlert = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            Picker("Modo", selection: $selectedTab) {
                Text("Rápida").tag(0)
                Text("Avançada").tag(1)
                Text("Presets").tag(2)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            TabView(selection: $selectedTab) {
                // Tab 0: Calibração Rápida
                quickCalibrationView
                    .tag(0)

                // Tab 1: Calibração Avançada
                advancedCalibrationView
                    .tag(1)

                // Tab 2: Presets
                presetsView
                    .tag(2)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        }
        .navigationTitle("Calibração MicroRec")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if calibrationService.isCalibrated {
                    Button("Resetar") {
                        showingResetAlert = true
                    }
                    .foregroundColor(.red)
                }
            }
        }
        .alert("Resetar Calibração?", isPresented: $showingResetAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Resetar", role: .destructive) {
                calibrationService.resetCalibration()
                appState.microRecCalibrated = false
            }
        } message: {
            Text("Isso removerá todas as configurações de calibração.")
        }
        .onAppear {
            if let data = calibrationService.calibrationData {
                rotationOffset = data.rotationOffset
            }
        }
    }

    // MARK: - Quick Calibration
    private var quickCalibrationView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Status
                calibrationStatusCard

                // Ajuste de rotação
                VStack(spacing: 16) {
                    Text("Ajuste de Rotação")
                        .font(.headline)

                    Text("Ajuste o offset de rotação do microscópio para corrigir o alinhamento da imagem.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    // Slider de rotação
                    VStack(spacing: 8) {
                        HStack {
                            Text("-10°")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.1f°", rotationOffset))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                            Spacer()
                            Text("+10°")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $rotationOffset, in: -10...10, step: 0.5)
                            .accentColor(.blue)

                        // Botões de ajuste fino
                        HStack(spacing: 20) {
                            Button {
                                rotationOffset = max(-10, rotationOffset - 0.5)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title2)
                            }

                            Button {
                                rotationOffset = 0
                            } label: {
                                Text("0°")
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(8)
                            }

                            Button {
                                rotationOffset = min(10, rotationOffset + 0.5)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                            }
                        }
                        .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding(.horizontal)

                // Botão de aplicar
                Button {
                    calibrationService.quickCalibrate(
                        rotationOffset: rotationOffset,
                        zoomLevel: appState.cameraZoomLevel
                    )
                    appState.microRecCalibrated = true
                    dismiss()
                } label: {
                    Label("Aplicar Calibração Rápida", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }

    // MARK: - Advanced Calibration
    private var advancedCalibrationView: some View {
        VStack(spacing: 24) {
            // Ícone
            Image(systemName: "camera.metering.matrix")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .padding(.top, 20)

            Text("Calibração Completa")
                .font(.title2)
                .fontWeight(.bold)

            Text("Siga os passos para calibrar distorção, escala e rotação.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Instruções
            VStack(alignment: .leading, spacing: 16) {
                CalibrationStep(number: 1, text: "Conecte o MicroRec ao microscópio Zeiss", isComplete: step >= 1)
                CalibrationStep(number: 2, text: "Posicione o iPhone no adaptador", isComplete: step >= 2)
                CalibrationStep(number: 3, text: "Foque em um alvo de calibração", isComplete: step >= 3)
                CalibrationStep(number: 4, text: "Capture imagem de referência", isComplete: step >= 4)
                CalibrationStep(number: 5, text: "Marque pontos de calibração", isComplete: step >= 5)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)

            Spacer()

            // Botão
            Button {
                if step < 5 {
                    step += 1
                } else {
                    // Calibração completa simulada
                    calibrationService.quickCalibrate(
                        rotationOffset: 0,
                        zoomLevel: appState.cameraZoomLevel
                    )
                    appState.microRecCalibrated = true
                    dismiss()
                }
            } label: {
                Text(step < 5 ? "Próximo Passo" : "Concluir Calibração")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding()
        }
    }

    // MARK: - Presets View
    private var presetsView: some View {
        List {
            Section {
                ForEach(MicroscopeCalibrationService.presets) { preset in
                    Button {
                        calibrationService.applyPreset(preset)
                        appState.microRecCalibrated = true
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(preset.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(preset.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("Perfis Pré-configurados")
            } footer: {
                Text("Selecione um preset para aplicar configurações otimizadas para seu equipamento.")
            }

            Section {
                HStack {
                    Text("Microscópio")
                    Spacer()
                    Text("Zeiss Opmi Lumera I")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Adaptador")
                    Spacer()
                    Text("MicroRec (Custom Surgical)")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Equipamento Suportado")
            }
        }
    }

    // MARK: - Status Card
    private var calibrationStatusCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: calibrationService.isCalibrated ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundColor(calibrationService.isCalibrated ? .green : .orange)

                VStack(alignment: .leading) {
                    Text(calibrationService.isCalibrated ? "Calibrado" : "Não Calibrado")
                        .font(.headline)
                    if let date = calibrationService.lastCalibrationDate {
                        Text("Última: \(formatDate(date))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()

                if calibrationService.isCalibrated {
                    VStack(alignment: .trailing) {
                        Text("Qualidade")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(calibrationService.calibrationQuality.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(qualityColor)
                    }
                }
            }

            if calibrationService.isCalibrated,
               let data = calibrationService.calibrationData {
                Divider()
                HStack {
                    VStack {
                        Text("Rotação")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f°", data.rotationOffset))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    Spacer()
                    VStack {
                        Text("Escala")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.2fx", data.scaleFactor))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    Spacer()
                    VStack {
                        Text("Zoom")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1fx", data.zoomLevel))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private var qualityColor: Color {
        switch calibrationService.calibrationQuality {
        case .excellent: return .blue
        case .good: return .green
        case .acceptable: return .orange
        case .poor: return .red
        case .unknown: return .gray
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yy HH:mm"
        return formatter.string(from: date)
    }
}

struct CalibrationStep: View {
    let number: Int
    let text: String
    let isComplete: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isComplete ? Color.green : Color(.systemGray4))
                    .frame(width: 28, height: 28)

                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                } else {
                    Text("\(number)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }

            Text(text)
                .font(.subheadline)
                .foregroundColor(isComplete ? .secondary : .primary)
        }
    }
}

// MARK: - Gerenciamento de Dados
struct DataManagementView: View {
    @EnvironmentObject var patientStore: PatientStore
    @State private var showingExportSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingBackupSuccess = false
    @State private var backupURL: URL?
    @State private var isCreatingBackup = false
    @State private var storageInfo: StorageInfo?

    var body: some View {
        List {
            // MARK: - Estatísticas
            Section {
                HStack {
                    Text("Pacientes")
                    Spacer()
                    Text("\(patientStore.totalPatients)")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Casos Cirúrgicos")
                    Spacer()
                    Text("\(patientStore.totalCases)")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Casos Concluídos")
                    Spacer()
                    Text("\(patientStore.completedCases)")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Estatísticas")
            }

            // MARK: - Armazenamento
            Section {
                if let info = storageInfo {
                    HStack {
                        Text("Espaço utilizado")
                        Spacer()
                        Text(info.formattedSize)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Imagens salvas")
                        Spacer()
                        Text("\(info.imageCount)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Relatórios PDF")
                        Spacer()
                        Text("\(info.reportCount)")
                            .foregroundColor(.secondary)
                    }
                } else {
                    HStack {
                        Text("Carregando...")
                        Spacer()
                        ProgressView()
                    }
                }
            } header: {
                Text("Armazenamento")
            }

            // MARK: - Backup
            Section {
                Button {
                    createBackup()
                } label: {
                    HStack {
                        Label("Criar Backup", systemImage: "arrow.down.doc")
                        Spacer()
                        if isCreatingBackup {
                            ProgressView()
                        }
                    }
                }
                .disabled(isCreatingBackup)

                NavigationLink {
                    BackupListView()
                } label: {
                    Label("Ver Backups", systemImage: "folder")
                }
            } header: {
                Text("Backup")
            } footer: {
                Text("Backups são salvos localmente no dispositivo")
            }

            // MARK: - Relatórios
            Section {
                NavigationLink {
                    ReportsListView()
                } label: {
                    Label("Relatórios Gerados", systemImage: "doc.text")
                }
            } header: {
                Text("Relatórios PDF")
            }

            // MARK: - Limpar Dados
            Section {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("Apagar Todos os Dados", systemImage: "trash")
                        .foregroundColor(.red)
                }
            } footer: {
                Text("Esta ação removerá todos os pacientes, casos e imagens")
            }
        }
        .navigationTitle("Gerenciar Dados")
        .onAppear {
            loadStorageInfo()
        }
        .alert("Apagar todos os dados?", isPresented: $showingDeleteAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Apagar", role: .destructive) {
                patientStore.clearAllData()
                loadStorageInfo()
            }
        } message: {
            Text("Esta ação não pode ser desfeita. Todos os pacientes, casos e imagens serão removidos permanentemente.")
        }
        .alert("Backup criado", isPresented: $showingBackupSuccess) {
            Button("OK") {}
        } message: {
            Text("O backup foi salvo com sucesso")
        }
    }

    private func loadStorageInfo() {
        storageInfo = patientStore.getStorageInfo()
    }

    private func createBackup() {
        isCreatingBackup = true
        DispatchQueue.global(qos: .userInitiated).async {
            let url = patientStore.createBackup()
            DispatchQueue.main.async {
                isCreatingBackup = false
                backupURL = url
                if url != nil {
                    showingBackupSuccess = true
                }
                loadStorageInfo()
            }
        }
    }
}

// MARK: - Lista de Backups
struct BackupListView: View {
    @EnvironmentObject var patientStore: PatientStore
    @State private var backups: [URL] = []

    var body: some View {
        List {
            if backups.isEmpty {
                Text("Nenhum backup encontrado")
                    .foregroundColor(.secondary)
            } else {
                ForEach(backups, id: \.absoluteString) { url in
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.blue)

                        VStack(alignment: .leading) {
                            Text(url.lastPathComponent)
                                .font(.subheadline)

                            if let date = getCreationDate(for: url) {
                                Text(formatDate(date))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Backups")
        .onAppear {
            backups = patientStore.listBackups()
        }
    }

    private func getCreationDate(for url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.creationDateKey]).creationDate
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Lista de Relatórios
struct ReportsListView: View {
    @State private var reports: [URL] = []
    @State private var selectedReport: URL?
    @State private var showingShareSheet = false

    var body: some View {
        List {
            if reports.isEmpty {
                Text("Nenhum relatório gerado")
                    .foregroundColor(.secondary)
            } else {
                ForEach(reports, id: \.absoluteString) { url in
                    Button {
                        selectedReport = url
                        showingShareSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.red)

                            VStack(alignment: .leading) {
                                Text(url.lastPathComponent)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)

                                if let size = getFileSize(for: url) {
                                    Text(size)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("Relatórios")
        .onAppear {
            loadReports()
        }
        .sheet(isPresented: $showingShareSheet) {
            if let url = selectedReport {
                ShareSheet(items: [url])
            }
        }
    }

    private func loadReports() {
        let reportsDir = DataPersistenceService.shared.getReportsDirectory()
        reports = (try? FileManager.default.contentsOfDirectory(
            at: reportsDir,
            includingPropertiesForKeys: [.fileSizeKey],
            options: .skipsHiddenFiles
        ).filter { $0.pathExtension == "pdf" }) ?? []
    }

    private func getFileSize(for url: URL) -> String? {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
            return nil
        }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}

// MARK: - Sobre
struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Logo
                Image(systemName: "eye.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(.top, 40)

                Text("ToricGuide")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Versão 1.0.0")
                    .foregroundColor(.secondary)

                Divider()
                    .padding(.horizontal, 40)

                VStack(spacing: 12) {
                    Text("Aplicativo para guiar a implantação de lentes intraoculares tóricas durante cirurgia de catarata.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)

                    Text("Compatível com:")
                        .fontWeight(.medium)
                        .padding(.top)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("iPhone 11 ou superior", systemImage: "iphone")
                        Label("MicroRec (Custom Surgical)", systemImage: "camera.aperture")
                        Label("Zeiss Opmi Lumera I", systemImage: "eye")
                    }
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                Spacer()

                Text("CEDOA © 2025")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Desenvolvido para uso profissional em oftalmologia")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 40)
            }
        }
        .navigationTitle("Sobre")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environmentObject(AppState())
    .environmentObject(PatientStore.preview)
}
