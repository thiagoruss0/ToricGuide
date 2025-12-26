//
//  ReferenceConfirmationView.swift
//  ToricGuide
//
//  Tela de confirmação da imagem de referência capturada
//

import SwiftUI

struct ReferenceConfirmationView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var patientStore: PatientStore
    @Environment(\.dismiss) private var dismiss

    var capturedImage: UIImage? {
        guard let data = appState.currentCase?.referenceImageData else { return nil }
        return UIImage(data: data)
    }

    var landmarks: EyeLandmarks? {
        appState.currentCase?.referenceLandmarks
    }

    var body: some View {
        VStack(spacing: 0) {
            // Imagem capturada
            imageSection

            // Landmarks detectados
            landmarksSection

            // Botões de ação
            actionButtons
        }
        .navigationTitle("Confirmar Referência")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Refazer") {
                    retakePhoto()
                }
            }
        }
    }

    // MARK: - Image Section
    private var imageSection: some View {
        GeometryReader { geometry in
            ZStack {
                // Fundo
                Color.black

                // Imagem
                if let image = capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()

                    // Overlay com análise
                    imageOverlay(size: geometry.size)
                } else {
                    VStack {
                        Image(systemName: "photo")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("Imagem não disponível")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .frame(height: 350)
    }

    // MARK: - Image Overlay
    private func imageOverlay(size: CGSize) -> some View {
        ZStack {
            // Círculo do limbo detectado
            if let landmarks = landmarks {
                Circle()
                    .stroke(Color.green, lineWidth: 2)
                    .frame(
                        width: size.width * landmarks.limbusRadius * 2,
                        height: size.width * landmarks.limbusRadius * 2
                    )

                // Linha do eixo 0°
                Rectangle()
                    .fill(Color.yellow)
                    .frame(width: size.width * 0.8, height: 2)

                // Indicador de eixo
                Text("Eixo 0°")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.yellow)
                    .padding(4)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(4)
                    .offset(x: size.width * 0.35)
            }
        }
    }

    // MARK: - Landmarks Section
    private var landmarksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LANDMARKS DETECTADOS")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.top, 16)

            VStack(spacing: 0) {
                LandmarkRow(
                    icon: "circle.circle",
                    title: "Limbo identificado",
                    isDetected: true
                )

                Divider().padding(.leading, 50)

                LandmarkRow(
                    icon: "circle.fill",
                    title: "Pupila centralizada",
                    isDetected: true
                )

                Divider().padding(.leading, 50)

                LandmarkRow(
                    icon: "line.diagonal",
                    title: "Vasos limbares mapeados",
                    value: landmarks != nil ? "\(landmarks!.limbalVessels.count) vasos" : "0 vasos",
                    isDetected: (landmarks?.limbalVessels.count ?? 0) > 0
                )

                Divider().padding(.leading, 50)

                LandmarkRow(
                    icon: "arrow.left.and.right",
                    title: "Eixo horizontal registrado",
                    value: landmarks != nil ? String(format: "%.1f°", landmarks!.referenceHorizontalAxis) : "0°",
                    isDetected: true
                )
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .padding(.horizontal)

            // Qualidade da captura
            if let quality = landmarks?.captureQuality {
                HStack {
                    Text("Qualidade da captura:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(quality.rawValue)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(qualityColor(quality))
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 16) {
            // Refazer
            Button {
                retakePhoto()
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("REFAZER")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray5))
                .foregroundColor(.primary)
                .cornerRadius(12)
            }

            // Confirmar
            Button {
                confirmAndProceed()
            } label: {
                HStack {
                    Image(systemName: "checkmark")
                    Text("CONFIRMAR")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
        .padding()
    }

    // MARK: - Helpers
    private func qualityColor(_ quality: CaptureQuality) -> Color {
        switch quality {
        case .excellent: return .green
        case .good: return .blue
        case .acceptable: return .orange
        case .poor: return .red
        }
    }

    private func retakePhoto() {
        // Voltar para captura
        appState.navigationPath.removeLast()
    }

    private func confirmAndProceed() {
        // Navegar para dados biométricos
        appState.navigationPath.append(AppRoute.biometricData)
    }
}

// MARK: - Landmark Row
struct LandmarkRow: View {
    let icon: String
    let title: String
    var value: String? = nil
    let isDetected: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            Image(systemName: isDetected ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isDetected ? .green : .red)
                .frame(width: 24)

            // Main icon
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)

            // Title
            Text(title)
                .font(.subheadline)

            Spacer()

            // Value if present
            if let value = value {
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

#Preview {
    NavigationStack {
        ReferenceConfirmationView()
    }
    .environmentObject(AppState())
    .environmentObject(PatientStore.preview)
}
