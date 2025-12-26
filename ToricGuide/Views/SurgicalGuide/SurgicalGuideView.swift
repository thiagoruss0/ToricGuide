//
//  SurgicalGuideView.swift
//  ToricGuide
//
//  Tela de guia cirúrgico intraoperatório
//  OTIMIZADA PARA LANDSCAPE - iPhone acoplado ao MicroRec horizontalmente
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
    @State private var showControls = true

    var targetAxis: Double {
        appState.currentCase?.calculatedAxis ?? 0
    }

    var displayAxis: Double {
        axisLocked ? correctedAxis : (targetAxis + manualAdjustment - detectedCyclotorsion)
    }

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height

            ZStack {
                // Fundo preto
                Color.black.ignoresSafeArea()

                // Câmera ao vivo
                CameraPreviewView(cameraService: cameraService)
                    .ignoresSafeArea()

                if isLandscape {
                    // LAYOUT LANDSCAPE - Otimizado para MicroRec
                    landscapeLayout(geometry: geometry)
                } else {
                    // LAYOUT PORTRAIT - Fallback
                    portraitLayout(geometry: geometry)
                }
            }
        }
        .navigationBarHidden(true)
        .statusBar(hidden: true)
        .persistentSystemOverlays(.hidden)
        .forceLandscape() // Força orientação landscape
        .onAppear {
            startSurgicalMode()
        }
        .onDisappear {
            stopSurgicalMode()
        }
        .onTapGesture {
            // Toque para mostrar/esconder controles
            withAnimation(.easeInOut(duration: 0.2)) {
                showControls.toggle()
            }
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

    // MARK: - Landscape Layout (Principal)
    private func landscapeLayout(geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            // PAINEL ESQUERDO - Informações
            if showControls {
                leftPanel
                    .frame(width: 180)
                    .transition(.move(edge: .leading))
            }

            // CENTRO - Overlay do olho (maximizado)
            ZStack {
                surgicalOverlay(geometry: geometry, isLandscape: true)

                // Indicador de eixo grande no centro superior
                VStack {
                    mainAxisIndicator
                        .padding(.top, 20)
                    Spacer()
                }
            }

            // PAINEL DIREITO - Controles
            if showControls {
                rightPanel
                    .frame(width: 180)
                    .transition(.move(edge: .trailing))
            }
        }
    }

    // MARK: - Portrait Layout (Fallback)
    private func portraitLayout(geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            if showControls {
                headerBar
            }

            Spacer()

            surgicalOverlay(geometry: geometry, isLandscape: false)

            Spacer()

            if showControls {
                VStack(spacing: 8) {
                    cyclotorsionInfoCompact
                    adjustmentControlsCompact
                }
            }
        }
    }

    // MARK: - Left Panel (Landscape)
    private var leftPanel: some View {
        VStack(spacing: 16) {
            // Botão Fechar
            Button {
                dismiss()
            } label: {
                HStack {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                    Text("Sair")
                        .font(.caption)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.8))
                .cornerRadius(8)
            }

            Divider().background(Color.white.opacity(0.3))

            // Informações do Paciente
            VStack(alignment: .leading, spacing: 8) {
                Text("PACIENTE")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))

                Text(appState.currentPatient?.name ?? "")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(2)

                HStack {
                    Text(appState.currentCase?.eye.rawValue ?? "")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue)
                        .cornerRadius(4)

                    if let iol = appState.currentCase?.selectedIOL {
                        Text(iol.toricity)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple)
                            .cornerRadius(4)
                    }
                }
                .foregroundColor(.white)
            }

            Divider().background(Color.white.opacity(0.3))

            // Ciclotorção
            VStack(spacing: 6) {
                Text("CICLOTORÇÃO")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))

                Text(String(format: "%+.1f°", detectedCyclotorsion))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(abs(detectedCyclotorsion) < 3 ? .green : .orange)
            }

            Divider().background(Color.white.opacity(0.3))

            // Eixo Alvo vs Atual
            VStack(spacing: 6) {
                HStack {
                    Text("Alvo:")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                    Text("\(Int(targetAxis))°")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }

                HStack {
                    Text("Atual:")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                    Text("\(Int(displayAxis))°")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.cyan)
                }
            }

            Spacer()

            // Status de alinhamento
            HStack(spacing: 6) {
                Circle()
                    .fill(isAligned ? Color.green : Color.orange)
                    .frame(width: 12, height: 12)

                Text(isAligned ? "ALINHADO" : "AJUSTAR")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(isAligned ? .green : .orange)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.5))
            .cornerRadius(8)
        }
        .padding(12)
        .background(Color.black.opacity(0.7))
    }

    // MARK: - Right Panel (Landscape)
    private var rightPanel: some View {
        VStack(spacing: 12) {
            // Ajuste de eixo
            Text("AJUSTE FINO")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))

            HStack(spacing: 8) {
                // -5°
                AdjustmentButtonLandscape(label: "-5", size: .small) {
                    adjustAxis(by: -5)
                }

                // -1°
                AdjustmentButtonLandscape(label: "-1", size: .large) {
                    adjustAxis(by: -1)
                }
            }

            HStack(spacing: 8) {
                // +1°
                AdjustmentButtonLandscape(label: "+1", size: .large) {
                    adjustAxis(by: 1)
                }

                // +5°
                AdjustmentButtonLandscape(label: "+5", size: .small) {
                    adjustAxis(by: 5)
                }
            }

            Divider().background(Color.white.opacity(0.3))

            // Travar Eixo
            Button {
                withAnimation(.spring()) {
                    axisLocked.toggle()
                }
                if axisLocked {
                    correctedAxis = displayAxis
                    HapticFeedback.success()
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: axisLocked ? "lock.fill" : "lock.open")
                        .font(.system(size: 24))
                    Text(axisLocked ? "TRAVADO" : "TRAVAR")
                        .font(.caption2)
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(axisLocked ? Color.orange : Color.blue)
                .cornerRadius(10)
            }

            Spacer()

            // Capturar foto
            Button {
                captureSnapshot()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 20))
                    Text("Capturar")
                        .font(.caption2)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.gray.opacity(0.6))
                .cornerRadius(8)
            }

            // Concluir
            Button {
                showingCompletionAlert = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                    Text("CONCLUIR")
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.green)
                .cornerRadius(10)
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.7))
    }

    // MARK: - Main Axis Indicator (Centro)
    private var mainAxisIndicator: some View {
        HStack(spacing: 16) {
            // Eixo Alvo
            VStack(spacing: 2) {
                Text("ALVO")
                    .font(.caption2)
                    .foregroundColor(.yellow.opacity(0.7))
                Text("\(Int(targetAxis))°")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.yellow)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.6))
            .cornerRadius(8)

            // Eixo Atual (grande)
            VStack(spacing: 2) {
                Text(axisLocked ? "TRAVADO" : "ATUAL")
                    .font(.caption2)
                    .foregroundColor(axisLocked ? .orange.opacity(0.7) : .cyan.opacity(0.7))
                Text("\(Int(displayAxis))°")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(axisLocked ? .orange : .cyan)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.7))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(axisLocked ? Color.orange : Color.cyan, lineWidth: 2)
            )

            // Desvio
            VStack(spacing: 2) {
                Text("DESVIO")
                    .font(.caption2)
                    .foregroundColor(isAligned ? .green.opacity(0.7) : .red.opacity(0.7))
                Text("\(Int(abs(displayAxis - targetAxis)))°")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(isAligned ? .green : .red)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.6))
            .cornerRadius(8)
        }
    }

    // MARK: - Surgical Overlay
    private func surgicalOverlay(geometry: GeometryProxy, isLandscape: Bool) -> some View {
        let availableWidth = isLandscape ? geometry.size.width - 360 : geometry.size.width
        let availableHeight = isLandscape ? geometry.size.height : geometry.size.height - 200
        let overlaySize = min(availableWidth, availableHeight) * 0.85

        let center = CGPoint(
            x: isLandscape ? availableWidth / 2 + 180 : geometry.size.width / 2,
            y: geometry.size.height / 2
        )
        let radius: CGFloat = overlaySize / 2

        return ZStack {
            // Círculo de referência (limbo)
            Circle()
                .stroke(Color.green.opacity(0.6), lineWidth: 3)
                .frame(width: radius * 2, height: radius * 2)
                .position(center)

            // Linha do eixo alvo (tracejada amarela)
            AxisLine(
                center: center,
                length: radius * 2.4,
                angle: targetAxis,
                color: .yellow.opacity(0.6),
                isDashed: true,
                lineWidth: 2
            )

            // Linha do eixo atual (sólida cyan/orange)
            AxisLine(
                center: center,
                length: radius * 2.4,
                angle: displayAxis,
                color: axisLocked ? .orange : (isAligned ? .green : .cyan),
                isDashed: false,
                lineWidth: 4
            )

            // Marcadores de graus ao redor
            ForEach([0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330], id: \.self) { angle in
                DegreeMarkerLandscape(
                    center: center,
                    radius: radius + 25,
                    angle: Double(angle),
                    isHighlighted: abs(Double(angle) - displayAxis.normalizedAngle) < 10 ||
                                  abs(Double(angle) - targetAxis) < 10,
                    isMajor: angle % 90 == 0
                )
            }

            // Indicador de alinhamento no centro
            if isAligned && !axisLocked {
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)

                    Text("ALINHADO")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(6)
                }
                .position(center)
            }
        }
    }

    // MARK: - Compact Controls (Portrait)
    private var cyclotorsionInfoCompact: some View {
        HStack(spacing: 20) {
            InfoPill(
                title: "Ciclotorção",
                value: String(format: "%.1f°", detectedCyclotorsion),
                color: abs(detectedCyclotorsion) < 3 ? .green : .orange
            )

            InfoPill(
                title: "Eixo",
                value: "\(Int(targetAxis))° → \(Int(displayAxis))°",
                color: .cyan
            )

            HStack(spacing: 6) {
                Circle()
                    .fill(isAligned ? Color.green : Color.orange)
                    .frame(width: 10, height: 10)
                Text(isAligned ? "OK" : "Ajustar")
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.6))
            .cornerRadius(20)
        }
    }

    private var adjustmentControlsCompact: some View {
        HStack(spacing: 12) {
            AdjustmentButton(label: "-1°") { adjustAxis(by: -1) }

            Button {
                withAnimation(.spring()) { axisLocked.toggle() }
                if axisLocked { correctedAxis = displayAxis }
            } label: {
                HStack {
                    Image(systemName: axisLocked ? "lock.fill" : "lock.open")
                    Text(axisLocked ? "TRAVADO" : "TRAVAR")
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(axisLocked ? Color.orange : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }

            AdjustmentButton(label: "+1°") { adjustAxis(by: 1) }

            Button { showingCompletionAlert = true } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color.black.opacity(0.7))
    }

    // MARK: - Header Bar (Portrait)
    private var headerBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.8))
            }

            Spacer()

            VStack(spacing: 2) {
                Text("Guia Cirúrgico")
                    .font(.headline)
                    .foregroundColor(.white)
                Text(appState.currentPatient?.name ?? "")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            Button { captureSnapshot() } label: {
                Image(systemName: "camera.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding()
        .background(Color.black.opacity(0.6))
    }

    // MARK: - Helper Methods
    private func startSurgicalMode() {
        // Manter tela ligada
        UIApplication.shared.isIdleTimerDisabled = true

        // Configurar câmera traseira para MicroRec
        cameraService.setupCamera(useFrontCamera: false)
        cameraService.startSession()

        // Iniciar rastreamento
        visionService.startTracking()

        // Detectar ciclotorção
        simulateCyclotorsionDetection()
        updateAlignment()
    }

    private func stopSurgicalMode() {
        UIApplication.shared.isIdleTimerDisabled = false
        cameraService.stopSession()
        visionService.stopTracking()
    }

    private func simulateCyclotorsionDetection() {
        detectedCyclotorsion = Double.random(in: -5...5)
        updateAlignment()
    }

    private func adjustAxis(by degrees: Double) {
        guard !axisLocked else {
            HapticFeedback.warning()
            return
        }

        withAnimation(.easeInOut(duration: 0.15)) {
            manualAdjustment += degrees
            updateAlignment()
        }

        HapticFeedback.light()
    }

    private func updateAlignment() {
        let deviation = abs(displayAxis - targetAxis)
        isAligned = deviation < 5
    }

    private func captureSnapshot() {
        cameraService.capturePhoto { image in
            if let image = image {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                HapticFeedback.success()
            }
        }
    }

    private func completeSurgery() {
        if var currentCase = appState.currentCase {
            currentCase.finalIOLAxis = displayAxis
            currentCase.intraopCyclotorsion = detectedCyclotorsion
            currentCase.status = .completed
            currentCase.completedAt = Date()

            appState.currentCase = currentCase
            patientStore.updateCase(currentCase)
        }

        appState.navigationPath = NavigationPath()
    }
}

// MARK: - Landscape-Optimized Components

struct AdjustmentButtonLandscape: View {
    let label: String
    let size: ButtonSize
    let action: () -> Void

    enum ButtonSize {
        case small, large

        var width: CGFloat {
            switch self {
            case .small: return 50
            case .large: return 65
            }
        }

        var height: CGFloat {
            switch self {
            case .small: return 40
            case .large: return 50
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .small: return 14
            case .large: return 18
            }
        }
    }

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: size.fontSize, weight: .bold))
                .frame(width: size.width, height: size.height)
                .background(Color.white.opacity(0.2))
                .foregroundColor(.white)
                .cornerRadius(8)
        }
    }
}

struct DegreeMarkerLandscape: View {
    let center: CGPoint
    let radius: CGFloat
    let angle: Double
    let isHighlighted: Bool
    let isMajor: Bool

    var body: some View {
        let radians = (90 - angle) * .pi / 180
        let x = center.x + radius * cos(radians)
        let y = center.y - radius * sin(radians)

        Text("\(Int(angle))°")
            .font(.system(size: isMajor ? 14 : 10, weight: isMajor ? .bold : .regular))
            .foregroundColor(isHighlighted ? .cyan : (isMajor ? .white.opacity(0.7) : .white.opacity(0.4)))
            .position(x: x, y: y)
    }
}

// MARK: - Original Supporting Views

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
                dash: isDashed ? [10, 5] : []
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

// MARK: - Eye Tracking Service
class EyeTrackingService: ObservableObject {
    @Published var isTracking = false
    @Published var detectedRotation: Double = 0

    func startTracking() {
        isTracking = true
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
