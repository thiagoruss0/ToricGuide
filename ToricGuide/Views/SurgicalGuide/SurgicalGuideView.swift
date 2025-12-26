//
//  SurgicalGuideView.swift
//  ToricGuide
//
//  Tela de guia cirúrgico intraoperatório
//  Exibe overlay do eixo sobre imagem ao vivo do MicroRec
//

import SwiftUI

struct SurgicalGuideView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var patientStore: PatientStore
    @Environment(\.dismiss) private var dismiss

    @StateObject private var cameraService = CameraService()
    @StateObject private var visionService = EyeTrackingService()

    // Estado do guia
    @State private var detectedCyclotorsion: Double = 0
    @State private var correctedAxis: Double = 0
    @State private var isAligned = false
    @State private var axisLocked = false
    @State private var manualAdjustment: Double = 0

    // UI State
    @State private var showingCompletionAlert = false
    @State private var isRecording = false

    var targetAxis: Double {
        appState.currentCase?.calculatedAxis ?? 0
    }

    var displayAxis: Double {
        axisLocked ? correctedAxis : (targetAxis + manualAdjustment - detectedCyclotorsion)
    }

    var body: some View {
        ZStack {
            // Fundo preto
            Color.black.ignoresSafeArea()

            // Câmera ao vivo
            CameraPreviewView(cameraService: cameraService)
                .ignoresSafeArea()

            // Overlay do guia
            surgicalOverlay

            // Controles
            VStack {
                // Header
                headerBar

                Spacer()

                // Informações de ciclotorção
                cyclotorsionInfo

                // Controles de ajuste
                adjustmentControls
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            startSurgicalMode()
        }
        .onDisappear {
            stopSurgicalMode()
        }
        .alert("Concluir Cirurgia?", isPresented: $showingCompletionAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Concluir") {
                completeSurgery()
            }
        } message: {
            Text("O eixo final será registrado como \(Int(displayAxis))°")
        }
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack {
            // Botão fechar
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.8))
            }

            Spacer()

            // Título
            VStack(spacing: 2) {
                Text("Guia Cirúrgico")
                    .font(.headline)
                    .foregroundColor(.white)

                Text(appState.currentPatient?.name ?? "")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            // Botão de captura/gravação
            Button {
                captureSnapshot()
            } label: {
                Image(systemName: isRecording ? "record.circle.fill" : "camera.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(isRecording ? .red : .white.opacity(0.8))
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [.black.opacity(0.7), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Surgical Overlay
    private var surgicalOverlay: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius: CGFloat = min(geometry.size.width, geometry.size.height) * 0.35

            ZStack {
                // Círculo de referência (limbo)
                Circle()
                    .stroke(Color.green.opacity(0.6), lineWidth: 2)
                    .frame(width: radius * 2, height: radius * 2)
                    .position(center)

                // Linha do eixo alvo (tracejada)
                AxisLine(
                    center: center,
                    length: radius * 2.2,
                    angle: targetAxis,
                    color: .yellow.opacity(0.5),
                    isDashed: true
                )

                // Linha do eixo corrigido/atual (sólida)
                AxisLine(
                    center: center,
                    length: radius * 2.2,
                    angle: displayAxis,
                    color: isAligned ? .green : .cyan,
                    isDashed: false,
                    lineWidth: 3
                )

                // Marcadores de graus
                ForEach([0, 45, 90, 135, 180, 225, 270, 315], id: \.self) { angle in
                    DegreeMarker(
                        center: center,
                        radius: radius + 20,
                        angle: Double(angle),
                        isHighlighted: abs(Double(angle) - displayAxis) < 5
                    )
                }

                // Indicador de eixo atual
                AxisIndicator(
                    center: center,
                    radius: radius + 50,
                    angle: displayAxis,
                    text: "\(Int(displayAxis))°",
                    isLocked: axisLocked
                )

                // Indicador de alinhamento
                if isAligned {
                    alignmentIndicator(center: center)
                }
            }
        }
    }

    // MARK: - Alignment Indicator
    private func alignmentIndicator(center: CGPoint) -> some View {
        VStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 40))
                .foregroundColor(.green)

            Text("ALINHADO")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.green)
        }
        .position(x: center.x, y: center.y - 80)
    }

    // MARK: - Cyclotorsion Info
    private var cyclotorsionInfo: some View {
        VStack(spacing: 8) {
            HStack(spacing: 20) {
                InfoPill(
                    title: "Ciclotorção",
                    value: String(format: "%.1f°", detectedCyclotorsion),
                    color: abs(detectedCyclotorsion) < 3 ? .green : .orange
                )

                InfoPill(
                    title: "Eixo Corrigido",
                    value: "\(Int(targetAxis))° → \(Int(displayAxis))°",
                    color: .cyan
                )
            }

            // Status de alinhamento
            HStack(spacing: 8) {
                Circle()
                    .fill(isAligned ? Color.green : Color.orange)
                    .frame(width: 10, height: 10)

                Text(isAligned ? "Alinhado (desvio < 5°)" : "Ajuste necessário")
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.6))
            .cornerRadius(20)
        }
        .padding(.bottom, 16)
    }

    // MARK: - Adjustment Controls
    private var adjustmentControls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                // Botão -1°
                AdjustmentButton(label: "-1°") {
                    adjustAxis(by: -1)
                }

                // Botão travar eixo
                Button {
                    withAnimation(.spring()) {
                        axisLocked.toggle()
                    }
                    if axisLocked {
                        correctedAxis = displayAxis
                    }
                } label: {
                    HStack {
                        Image(systemName: axisLocked ? "lock.fill" : "lock.open")
                        Text(axisLocked ? "TRAVADO" : "TRAVAR EIXO")
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(axisLocked ? Color.orange : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }

                // Botão +1°
                AdjustmentButton(label: "+1°") {
                    adjustAxis(by: 1)
                }
            }

            // Botão concluir
            Button {
                showingCompletionAlert = true
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("CONCLUIR CIRURGIA")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Helper Methods
    private func startSurgicalMode() {
        // Configurar câmera traseira para MicroRec
        cameraService.setupCamera(useFrontCamera: false)
        cameraService.startSession()

        // Iniciar rastreamento de olho
        visionService.startTracking()

        // Simular detecção de ciclotorção (em produção, viria do Vision)
        simulateCyclotorsionDetection()

        // Calcular eixo corrigido
        updateAlignment()
    }

    private func stopSurgicalMode() {
        cameraService.stopSession()
        visionService.stopTracking()
    }

    private func simulateCyclotorsionDetection() {
        // Em produção, isso viria da comparação entre
        // a imagem de referência e a imagem ao vivo
        // Por enquanto, simular um valor
        detectedCyclotorsion = Double.random(in: -5...5)
        updateAlignment()
    }

    private func adjustAxis(by degrees: Double) {
        guard !axisLocked else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            manualAdjustment += degrees
            updateAlignment()
        }

        // Feedback háptico
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private func updateAlignment() {
        let deviation = abs(displayAxis - targetAxis)
        isAligned = deviation < 5
    }

    private func captureSnapshot() {
        cameraService.capturePhoto { image in
            // Salvar snapshot
            if let image = image {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)

                // Feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        }
    }

    private func completeSurgery() {
        // Salvar resultado final
        if var currentCase = appState.currentCase {
            currentCase.finalIOLAxis = displayAxis
            currentCase.intraopCyclotorsion = detectedCyclotorsion
            currentCase.status = .completed
            currentCase.completedAt = Date()

            appState.currentCase = currentCase
            patientStore.updateCase(currentCase)
        }

        // Voltar para home
        appState.navigationPath = NavigationPath()
    }
}

// MARK: - Supporting Views

struct AxisLine: View {
    let center: CGPoint
    let length: CGFloat
    let angle: Double
    let color: Color
    var isDashed: Bool = false
    var lineWidth: CGFloat = 2

    var body: some View {
        Path { path in
            let radians = (90 - angle) * .pi / 180
            let dx = length / 2 * cos(radians)
            let dy = length / 2 * sin(radians)

            path.move(to: CGPoint(x: center.x - dx, y: center.y + dy))
            path.addLine(to: CGPoint(x: center.x + dx, y: center.y - dy))
        }
        .stroke(
            color,
            style: StrokeStyle(
                lineWidth: lineWidth,
                dash: isDashed ? [8, 4] : []
            )
        )
    }
}

struct DegreeMarker: View {
    let center: CGPoint
    let radius: CGFloat
    let angle: Double
    let isHighlighted: Bool

    var body: some View {
        let radians = (90 - angle) * .pi / 180
        let x = center.x + radius * cos(radians)
        let y = center.y - radius * sin(radians)

        Text("\(Int(angle))°")
            .font(.system(size: isHighlighted ? 14 : 10))
            .fontWeight(isHighlighted ? .bold : .regular)
            .foregroundColor(isHighlighted ? .cyan : .white.opacity(0.5))
            .position(x: x, y: y)
    }
}

struct AxisIndicator: View {
    let center: CGPoint
    let radius: CGFloat
    let angle: Double
    let text: String
    let isLocked: Bool

    var body: some View {
        let radians = (90 - angle) * .pi / 180
        let x = center.x + radius * cos(radians)
        let y = center.y - radius * sin(radians)

        HStack(spacing: 4) {
            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.caption2)
            }
            Text(text)
                .font(.headline)
                .fontWeight(.bold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isLocked ? Color.orange : Color.cyan)
        .foregroundColor(.white)
        .cornerRadius(8)
        .position(x: x, y: y)
    }
}

struct InfoPill: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.6))
        .cornerRadius(8)
    }
}

struct AdjustmentButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.headline)
                .frame(width: 60, height: 50)
                .background(Color(.systemGray5))
                .foregroundColor(.primary)
                .cornerRadius(10)
        }
    }
}

// MARK: - Eye Tracking Service (placeholder)
class EyeTrackingService: ObservableObject {
    @Published var isTracking = false
    @Published var detectedRotation: Double = 0

    func startTracking() {
        isTracking = true
        // Em produção: usar Vision framework para comparar
        // imagem de referência com imagem ao vivo
    }

    func stopTracking() {
        isTracking = false
    }
}

#Preview {
    SurgicalGuideView()
        .environmentObject(AppState())
        .environmentObject(PatientStore.preview)
}
