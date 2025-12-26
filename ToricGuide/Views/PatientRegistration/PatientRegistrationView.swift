//
//  PatientRegistrationView.swift
//  ToricGuide
//
//  Tela de cadastro do paciente e seleção do olho
//

import SwiftUI

struct PatientRegistrationView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var patientStore: PatientStore

    // Campos do formulário
    @State private var patientName = ""
    @State private var medicalRecordNumber = ""
    @State private var selectedEye: Eye = .right
    @State private var surgeryDate = Date()

    // Validação
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""

    // Foco do teclado
    @FocusState private var focusedField: Field?

    enum Field {
        case name, record
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // MARK: - Identificação do Paciente
                formSection(title: "IDENTIFICAÇÃO DO PACIENTE") {
                    VStack(spacing: 16) {
                        // Nome
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Nome")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            TextField("Nome completo do paciente", text: $patientName)
                                .textFieldStyle(CustomTextFieldStyle())
                                .textContentType(.name)
                                .autocapitalization(.words)
                                .focused($focusedField, equals: .name)
                        }

                        // Prontuário
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Prontuário")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            TextField("Número do prontuário", text: $medicalRecordNumber)
                                .textFieldStyle(CustomTextFieldStyle())
                                .keyboardType(.default)
                                .focused($focusedField, equals: .record)
                        }
                    }
                }

                // MARK: - Olho a Operar
                formSection(title: "OLHO A OPERAR") {
                    HStack(spacing: 16) {
                        EyeSelectionButton(
                            eye: .right,
                            isSelected: selectedEye == .right
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedEye = .right
                            }
                        }

                        EyeSelectionButton(
                            eye: .left,
                            isSelected: selectedEye == .left
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedEye = .left
                            }
                        }
                    }
                }

                // MARK: - Data da Cirurgia
                formSection(title: "DATA DA CIRURGIA") {
                    DatePicker(
                        "",
                        selection: $surgeryDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .labelsHidden()
                }

                // MARK: - Botão Próximo
                Button(action: proceedToNextStep) {
                    HStack {
                        Text("PRÓXIMO")
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isFormValid ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!isFormValid)
                .padding(.top, 8)
            }
            .padding()
        }
        .navigationTitle("Novo Caso")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Atenção", isPresented: $showingValidationAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(validationMessage)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Feito") {
                    focusedField = nil
                }
            }
        }
    }

    // MARK: - Form Section Helper
    private func formSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .tracking(0.5)

            content()
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        }
    }

    // MARK: - Validação
    private var isFormValid: Bool {
        !patientName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Próximo Passo
    private func proceedToNextStep() {
        guard isFormValid else {
            validationMessage = "Por favor, preencha o nome do paciente."
            showingValidationAlert = true
            return
        }

        // Criar paciente
        let patient = Patient(
            name: patientName.trimmingCharacters(in: .whitespaces),
            medicalRecordNumber: medicalRecordNumber.trimmingCharacters(in: .whitespaces)
        )

        // Criar caso cirúrgico
        let surgicalCase = SurgicalCase(
            patientId: patient.id,
            eye: selectedEye,
            surgeryDate: surgeryDate
        )

        // Salvar no store
        patientStore.addPatient(patient)
        patientStore.addCase(surgicalCase)

        // Atualizar estado global
        appState.currentPatient = patient
        appState.currentCase = surgicalCase

        // Navegar para captura de referência
        appState.navigationPath.append(AppRoute.referenceCapture)
    }
}

// MARK: - Botão de Seleção do Olho
struct EyeSelectionButton: View {
    let eye: Eye
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                // Ícone do olho
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.blue : Color(.systemGray5))
                        .frame(width: 70, height: 70)

                    // Olho estilizado
                    Image(systemName: "eye.fill")
                        .font(.system(size: 28))
                        .foregroundColor(isSelected ? .white : .gray)
                        .scaleEffect(x: eye == .left ? -1 : 1, y: 1) // Espelhar para OE
                }

                // Badge de seleção
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 20))
                }

                // Labels
                VStack(spacing: 2) {
                    Text(eye.rawValue)
                        .font(.headline)
                        .fontWeight(.bold)

                    Text(eye.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Custom TextField Style
struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(14)
            .background(Color(.systemGray6))
            .cornerRadius(10)
    }
}

#Preview {
    NavigationStack {
        PatientRegistrationView()
    }
    .environmentObject(AppState())
    .environmentObject(PatientStore())
}
