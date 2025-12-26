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

// MARK: - Calibração MicroRec
struct MicroRecCalibrationView: View {
    @EnvironmentObject var appState: AppState
    @State private var step = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // Ícone
            Image(systemName: "camera.metering.matrix")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .padding(.top, 40)

            Text("Calibração do MicroRec")
                .font(.title2)
                .fontWeight(.bold)

            // Instruções
            VStack(alignment: .leading, spacing: 16) {
                CalibrationStep(number: 1, text: "Conecte o MicroRec ao microscópio Zeiss", isComplete: step >= 1)
                CalibrationStep(number: 2, text: "Posicione o iPhone no adaptador", isComplete: step >= 2)
                CalibrationStep(number: 3, text: "Foque em um alvo de calibração", isComplete: step >= 3)
                CalibrationStep(number: 4, text: "Ajuste o zoom óptico", isComplete: step >= 4)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)

            Spacer()

            // Botão
            Button {
                if step < 4 {
                    step += 1
                } else {
                    appState.microRecCalibrated = true
                    dismiss()
                }
            } label: {
                Text(step < 4 ? "Próximo Passo" : "Concluir Calibração")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding()
        }
        .navigationTitle("Calibração")
        .navigationBarTitleDisplayMode(.inline)
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

    var body: some View {
        List {
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

            Section {
                Button {
                    showingExportSheet = true
                } label: {
                    Label("Exportar Dados", systemImage: "square.and.arrow.up")
                }

                Button {
                    // Importar dados
                } label: {
                    Label("Importar Dados", systemImage: "square.and.arrow.down")
                }
            } header: {
                Text("Backup")
            }

            Section {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("Apagar Todos os Dados", systemImage: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Gerenciar Dados")
        .alert("Apagar todos os dados?", isPresented: $showingDeleteAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Apagar", role: .destructive) {
                // Apagar dados
            }
        } message: {
            Text("Esta ação não pode ser desfeita.")
        }
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
