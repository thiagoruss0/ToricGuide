//
//  MicroRecCaptureView.swift
//  ToricGuide
//
//  Captura de referência via MicroRec (câmera traseira, landscape)
//  Para uso no centro cirúrgico, antes de iniciar a cirurgia
//

import SwiftUI
import AVFoundation

struct MicroRecCaptureView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var patientStore: PatientStore
    @Environment(\.dismiss) private var dismiss

    @StateObject private var cameraService = CameraService()

    @State private var isCapturing = false
    @State private var showControls = true

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height

            ZStack {
                // Fundo preto
                Color.black.ignoresSafeArea()

                // Preview da câmera
                CameraPreviewView(cameraService: cameraService)
                    .ignoresSafeArea()

                if isLandscape {
                    landscapeLayout(geometry: geometry)
                } else {
                    portraitLayout(geometry: geometry)
                }
            }
        }
        .navigationBarHidden(true)
        .statusBar(hidden: true)
        .forceLandscape()
        .onAppear {
            setupCamera()
        }
        .onDisappear {
            cameraService.stopSession()
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                showControls.toggle()
            }
        }
    }

    // MARK: - Landscape Layout
    private func landscapeLayout(geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            // Painel esquerdo - Instruções
            if showControls {
                leftPanel
                    .frame(width: 200)
                    .transition(.move(edge: .leading))
            }

            // Centro - Câmera com guias
            ZStack {
                cameraGuideOverlay(geometry: geometry, isLandscape: true)
            }

            // Painel direito - Controles
            if showControls {
                rightPanel
                    .frame(width: 160)
                    .transition(.move(edge: .trailing))
            }
        }
    }

    // MARK: - Portrait Layout (Fallback)
    private func portraitLayout(geometry: GeometryProxy) -> some View {
        VStack {
            if showControls {
                headerBar
            }

            Spacer()

            cameraGuideOverlay(geometry: geometry, isLandscape: false)

            Spacer()

            if showControls {
                captureButtonPortrait
            }
        }
    }

    // MARK: - Left Panel
    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Botão Voltar
            Button {
                dismiss()
            } label: {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Voltar")
                        .font(.caption)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.2))
                .cornerRadius(8)
            }

            Divider().background(Color.white.opacity(0.3))

            // Título
            VStack(alignment: .leading, spacing: 4) {
                Text("CAPTURA VIA MICROREC")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))

                Text("Referência Pré-Op")
                    .font(.headline)
                    .foregroundColor(.white)
            }

            Divider().background(Color.white.opacity(0.3))

            // Instruções
            VStack(alignment: .leading, spacing: 12) {
                InstructionRowLandscape(
                    icon: "eye",
                    text: "Centralize o olho",
                    isComplete: cameraService.eyeDetected
                )

                InstructionRowLandscape(
                    icon: "scope",
                    text: "Foque no limbo",
                    isComplete: true
                )

                InstructionRowLandscape(
                    icon: "light.max",
                    text: "Iluminação adequada",
                    isComplete: true
                )
            }

            Spacer()

            // Status
            HStack {
                Circle()
                    .fill(cameraService.eyeDetected ? Color.green : Color.orange)
                    .frame(width: 10, height: 10)

                Text(cameraService.eyeDetected ? "Pronto" : "Aguardando...")
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.5))
            .cornerRadius(8)
        }
        .padding(16)
        .background(Color.black.opacity(0.7))
    }

    // MARK: - Right Panel
    private var rightPanel: some View {
        VStack(spacing: 20) {
            Spacer()

            // Informações do paciente
            VStack(spacing: 4) {
                Text(appState.currentPatient?.name ?? "")
                    .font(.caption)
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(appState.currentCase?.eye.rawValue ?? "")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }

            Spacer()

            // Botão de captura grande
            Button {
                captureReference()
            } label: {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(Color.white, lineWidth: 4)
                            .frame(width: 80, height: 80)

                        Circle()
                            .fill(isCapturing ? Color.gray : Color.white)
                            .frame(width: 66, height: 66)

                        Image(systemName: "camera.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.black)
                    }

                    Text("CAPTURAR")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            .disabled(isCapturing)

            Spacer()
        }
        .padding(16)
        .background(Color.black.opacity(0.7))
    }

    // MARK: - Camera Guide Overlay
    private func cameraGuideOverlay(geometry: GeometryProxy, isLandscape: Bool) -> some View {
        let availableWidth = isLandscape ? geometry.size.width - 360 : geometry.size.width
        let availableHeight = isLandscape ? geometry.size.height : geometry.size.height - 150
        let overlaySize = min(availableWidth, availableHeight) * 0.75

        let center = CGPoint(
            x: isLandscape ? (availableWidth / 2) + 200 : geometry.size.width / 2,
            y: geometry.size.height / 2
        )

        return ZStack {
            // Círculo guia para o limbo
            Circle()
                .stroke(
                    cameraService.eyeDetected ? Color.green : Color.white.opacity(0.6),
                    lineWidth: 3
                )
                .frame(width: overlaySize, height: overlaySize)
                .position(center)

            // Cruz central
            Group {
                Rectangle()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 1, height: 50)

                Rectangle()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 50, height: 1)
            }
            .position(center)

            // Linha horizontal de referência (0°-180°)
            Rectangle()
                .fill(Color.yellow.opacity(0.7))
                .frame(width: overlaySize * 1.2, height: 2)
                .position(center)

            // Labels de eixo
            Text("0°")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.yellow)
                .position(x: center.x + overlaySize * 0.65, y: center.y)

            Text("180°")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.yellow)
                .position(x: center.x - overlaySize * 0.65, y: center.y)

            Text("90°")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .position(x: center.x, y: center.y - overlaySize * 0.55)

            Text("270°")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .position(x: center.x, y: center.y + overlaySize * 0.55)
        }
    }

    // MARK: - Portrait Components
    private var headerBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.8))
            }

            Spacer()

            Text("Captura MicroRec")
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            Color.clear.frame(width: 28, height: 28)
        }
        .padding()
        .background(Color.black.opacity(0.6))
    }

    private var captureButtonPortrait: some View {
        Button {
            captureReference()
        } label: {
            ZStack {
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 80, height: 80)

                Circle()
                    .fill(isCapturing ? Color.gray : Color.white)
                    .frame(width: 66, height: 66)

                Image(systemName: "camera.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.black)
            }
        }
        .disabled(isCapturing)
        .padding(.bottom, 40)
    }

    // MARK: - Methods
    private func setupCamera() {
        cameraService.setupCamera(useFrontCamera: false) // Câmera traseira para MicroRec
        cameraService.startSession()
    }

    private func captureReference() {
        isCapturing = true
        HapticFeedback.medium()

        cameraService.capturePhoto { image in
            isCapturing = false

            guard let capturedImage = image else {
                HapticFeedback.error()
                return
            }

            // Salvar imagem no caso
            if var currentCase = appState.currentCase {
                currentCase.referenceImageData = capturedImage.jpegData(compressionQuality: 0.8)
                currentCase.referenceImageTimestamp = Date()
                currentCase.status = .referenceCapured

                // Criar landmarks básicos
                currentCase.referenceLandmarks = EyeLandmarks(
                    limbusCenter: CGPointCodable(x: 0.5, y: 0.5),
                    limbusRadius: 0.35,
                    pupilCenter: CGPointCodable(x: 0.5, y: 0.5),
                    pupilRadius: 0.1,
                    limbalVessels: [],
                    referenceHorizontalAxis: 0, // Já está alinhado via MicroRec
                    captureQuality: .good
                )

                appState.currentCase = currentCase
                patientStore.updateCase(currentCase)
            }

            HapticFeedback.success()

            // Navegar para confirmação
            appState.navigationPath.append(AppRoute.referenceConfirmation)
        }
    }
}

// MARK: - Supporting Views
struct InstructionRowLandscape: View {
    let icon: String
    let text: String
    let isComplete: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isComplete ? .green : .gray)
                .font(.system(size: 14))

            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.7))
                .font(.system(size: 14))
                .frame(width: 20)

            Text(text)
                .font(.caption)
                .foregroundColor(isComplete ? .white : .white.opacity(0.6))
        }
    }
}

#Preview {
    MicroRecCaptureView()
        .environmentObject(AppState())
        .environmentObject(PatientStore.preview)
}
