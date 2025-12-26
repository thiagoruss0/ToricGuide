//
//  BiometricDataView.swift
//  ToricGuide
//
//  Tela de entrada dos dados biométricos e seleção da LIO
//

import SwiftUI

struct BiometricDataView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var patientStore: PatientStore

    // Ceratometria
    @State private var k1Power: String = "43.50"
    @State private var k1Axis: String = "180"
    @State private var k2Power: String = "45.25"
    @State private var k2Axis: String = "90"

    // LIO
    @State private var selectedManufacturer: IOLManufacturer = .alcon
    @State private var selectedModelIndex: Int = 0

    // Incisão
    @State private var incisionLocation: IncisionLocation = .temporal
    @State private var incisionSize: Double = 2.4
    @State private var siaValue: String = "0.30"

    // UI State
    @State private var showingIOLPicker = false
    @FocusState private var focusedField: Field?

    enum Field {
        case k1Power, k1Axis, k2Power, k2Axis, sia
    }

    // Computed properties
    var totalAstigmatism: Double {
        let k1 = Double(k1Power) ?? 0
        let k2 = Double(k2Power) ?? 0
        return abs(k2 - k1)
    }

    var astigmatismAxis: Double {
        Double(k2Axis) ?? 90
    }

    var availableModels: [String] {
        selectedManufacturer.models
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Resumo do paciente
                patientSummary

                // Ceratometria
                keratometrySection

                // Astigmatismo calculado
                astigmatismSummary

                // Modelo da LIO
                iolSection

                // Incisão
                incisionSection

                // Botão calcular
                calculateButton
            }
            .padding()
        }
        .navigationTitle("Dados Biométricos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Feito") {
                    focusedField = nil
                }
            }
        }
    }

    // MARK: - Patient Summary
    private var patientSummary: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(appState.currentPatient?.name ?? "Paciente")
                    .font(.headline)

                Text(appState.currentCase?.eye.fullDescription ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Mini preview da imagem de referência
            if let imageData = appState.currentCase?.referenceImageData,
               let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Keratometry Section
    private var keratometrySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CERATOMETRIA")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            VStack(spacing: 16) {
                // K1 - Meridiano mais plano
                HStack(spacing: 12) {
                    Text("K1")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(width: 30)

                    Text("(mais plano)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .leading)

                    NumericTextField(
                        value: $k1Power,
                        placeholder: "43.50",
                        suffix: "D"
                    )
                    .focused($focusedField, equals: .k1Power)

                    Text("Eixo:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    NumericTextField(
                        value: $k1Axis,
                        placeholder: "180",
                        suffix: "°"
                    )
                    .focused($focusedField, equals: .k1Axis)
                    .frame(width: 70)
                }

                // K2 - Meridiano mais curvo
                HStack(spacing: 12) {
                    Text("K2")
                        .font(.headline)
                        .foregroundColor(.orange)
                        .frame(width: 30)

                    Text("(mais curvo)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .leading)

                    NumericTextField(
                        value: $k2Power,
                        placeholder: "45.25",
                        suffix: "D"
                    )
                    .focused($focusedField, equals: .k2Power)

                    Text("Eixo:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    NumericTextField(
                        value: $k2Axis,
                        placeholder: "90",
                        suffix: "°"
                    )
                    .focused($focusedField, equals: .k2Axis)
                    .frame(width: 70)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        }
    }

    // MARK: - Astigmatism Summary
    private var astigmatismSummary: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Astigmatismo Corneano Total")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.2f", totalAstigmatism))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.blue)

                    Text("D")
                        .font(.headline)
                        .foregroundColor(.blue)

                    Text("@")
                        .foregroundColor(.secondary)

                    Text(String(format: "%.0f°", astigmatismAxis))
                        .font(.headline)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            // Tipo de astigmatismo
            let keratometry = Keratometry(
                k1Power: Double(k1Power) ?? 43,
                k1Axis: Double(k1Axis) ?? 180,
                k2Power: Double(k2Power) ?? 44,
                k2Axis: Double(k2Axis) ?? 90
            )

            VStack(alignment: .trailing, spacing: 4) {
                Text("Tipo")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(keratometry.astigmatismType.abbreviation)
                    .font(.headline)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.1))
                    .foregroundColor(.purple)
                    .cornerRadius(6)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - IOL Section
    private var iolSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MODELO DA LIO TÓRICA")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                // Fabricante
                HStack {
                    Text("Fabricante")
                        .foregroundColor(.secondary)
                    Spacer()
                    Picker("", selection: $selectedManufacturer) {
                        ForEach(IOLManufacturer.allCases, id: \.self) { manufacturer in
                            Text(manufacturer.rawValue).tag(manufacturer)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }

                Divider()

                // Modelo
                HStack {
                    Text("Modelo")
                        .foregroundColor(.secondary)
                    Spacer()
                    Picker("", selection: $selectedModelIndex) {
                        ForEach(0..<availableModels.count, id: \.self) { index in
                            Text(availableModels[index]).tag(index)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }

                Divider()

                // Sugestão automática
                if let suggested = IOLCatalog.findBestMatch(
                    targetCornealCylinder: totalAstigmatism,
                    manufacturer: selectedManufacturer
                ) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)

                        Text("Sugerido: \(suggested.shortName)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("(\(String(format: "%.2f", suggested.cylinderPowerAtCornea))D)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .padding(.top, 4)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        }
    }

    // MARK: - Incision Section
    private var incisionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("INCISÃO")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                // Localização
                HStack {
                    Text("Localização")
                        .foregroundColor(.secondary)
                    Spacer()
                    Picker("", selection: $incisionLocation) {
                        ForEach(IncisionLocation.allCases, id: \.self) { location in
                            Text(location.rawValue).tag(location)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }

                Divider()

                // Tamanho
                HStack {
                    Text("Tamanho")
                        .foregroundColor(.secondary)
                    Spacer()
                    Picker("", selection: $incisionSize) {
                        ForEach(IncisionSizes.common, id: \.self) { size in
                            Text(String(format: "%.1f mm", size)).tag(size)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }

                Divider()

                // SIA
                HStack {
                    Text("SIA esperado")
                        .foregroundColor(.secondary)

                    Spacer()

                    NumericTextField(
                        value: $siaValue,
                        placeholder: "0.30",
                        suffix: "D"
                    )
                    .focused($focusedField, equals: .sia)
                    .frame(width: 80)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        }
    }

    // MARK: - Calculate Button
    private var calculateButton: some View {
        Button {
            calculateAndProceed()
        } label: {
            HStack {
                Image(systemName: "function")
                Text("CALCULAR")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }

    // MARK: - Calculate
    private func calculateAndProceed() {
        // Criar dados de ceratometria
        let keratometry = Keratometry(
            k1Power: Double(k1Power) ?? 43.5,
            k1Axis: Double(k1Axis) ?? 180,
            k2Power: Double(k2Power) ?? 45.25,
            k2Axis: Double(k2Axis) ?? 90
        )

        // Criar dados de incisão
        let incision = IncisionData(
            location: incisionLocation,
            axis: incisionLocation.typicalAxis(for: appState.currentCase?.eye ?? .right),
            size: incisionSize,
            surgicallyInducedAstigmatism: Double(siaValue) ?? 0.30
        )

        // Encontrar melhor LIO
        let selectedIOL = IOLCatalog.findBestMatch(
            targetCornealCylinder: totalAstigmatism,
            manufacturer: selectedManufacturer
        )

        // Atualizar caso
        if var currentCase = appState.currentCase {
            currentCase.keratometry = keratometry
            currentCase.incision = incision
            currentCase.selectedIOL = selectedIOL

            // Calcular eixo de implantação
            // Fórmula simplificada: eixo = eixo do astigmatismo mais curvo (K2)
            // Em casos reais, usaria vetores e SIA
            currentCase.calculatedAxis = keratometry.k2Axis

            // Calcular astigmatismo residual
            if let iol = selectedIOL {
                currentCase.residualAstigmatism = abs(totalAstigmatism - iol.cylinderPowerAtCornea)
            }

            currentCase.status = .calculated
            appState.currentCase = currentCase
            patientStore.updateCase(currentCase)
        }

        // Navegar para resultados
        appState.navigationPath.append(AppRoute.results)
    }
}

// MARK: - Numeric TextField
struct NumericTextField: View {
    @Binding var value: String
    let placeholder: String
    var suffix: String = ""

    var body: some View {
        HStack(spacing: 4) {
            TextField(placeholder, text: $value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)

            if !suffix.isEmpty {
                Text(suffix)
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    NavigationStack {
        BiometricDataView()
    }
    .environmentObject(AppState())
    .environmentObject(PatientStore.preview)
}
