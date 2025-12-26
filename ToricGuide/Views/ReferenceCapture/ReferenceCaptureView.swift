//
//  ReferenceCaptureView.swift
//  ToricGuide
//
//  Tela de captura da imagem de referência (pré-operatório)
//  Paciente deve estar SENTADO para esta captura
//

import SwiftUI
import AVFoundation

struct ReferenceCaptureView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var patientStore: PatientStore

    @StateObject private var cameraService = CameraService()
    @StateObject private var motionService = MotionService()

    @State private var showInstructions = true
    @State private var isCapturing = false
    @State private var capturedImage: UIImage?
    @State private var showingPermissionAlert = false

    var body: some View {
        ZStack {
            // Fundo preto para câmera
            Color.black.ignoresSafeArea()

            if showInstructions {
                instructionsOverlay
            } else {
                cameraView
            }
        }
        .navigationTitle("Captura de Referência")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !showInstructions {
                    Button("Ajuda") {
                        showInstructions = true
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            checkCameraPermission()
        }
        .onDisappear {
            cameraService.stopSession()
            motionService.stopUpdates()
        }
        .alert("Permissão de Câmera", isPresented: $showingPermissionAlert) {
            Button("Configurações") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("O ToricGuide precisa de acesso à câmera para capturar a imagem de referência.")
        }
    }

    // MARK: - Instructions Overlay
    private var instructionsOverlay: some View {
        VStack(spacing: 24) {
            Spacer()

            // Ícone
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text("INSTRUÇÕES IMPORTANTES")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)

            // Lista de instruções
            VStack(alignment: .leading, spacing: 16) {
                InstructionRow(icon: "person.fill", text: "Paciente deve estar SENTADO")
                InstructionRow(icon: "face.smiling", text: "Cabeça reta, olhando para frente")
                InstructionRow(icon: "iphone.gen3", text: "Alinhe o iPhone horizontalmente")
                InstructionRow(icon: "lightbulb.fill", text: "Use iluminação adequada para visualizar vasos")
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(16)
            .padding(.horizontal)

            Spacer()

            // Botão iniciar
            Button {
                withAnimation {
                    showInstructions = false
                }
                startCamera()
            } label: {
                HStack {
                    Image(systemName: "camera.fill")
                    Text("INICIAR CAPTURA")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Camera View
    private var cameraView: some View {
        GeometryReader { geometry in
            ZStack {
                // Preview da câmera
                CameraPreviewView(cameraService: cameraService)
                    .ignoresSafeArea()

                // Overlay com guias
                VStack {
                    // Status bar
                    statusBar
                        .padding(.top, 60)

                    Spacer()

                    // Área central com guia de olho
                    eyeGuideOverlay(size: geometry.size)

                    Spacer()

                    // Indicador de nível
                    LevelIndicatorView(motionService: motionService)
                        .padding(.horizontal)

                    // Botão de captura
                    captureButton
                        .padding(.bottom, 40)
                }
            }
        }
    }

    // MARK: - Status Bar
    private var statusBar: some View {
        HStack(spacing: 16) {
            // Status do nível
            StatusIndicator(
                icon: "level.fill",
                text: "iPhone nivelado",
                isActive: motionService.isLeveled
            )

            // Status do olho
            StatusIndicator(
                icon: "eye.fill",
                text: "Olho detectado",
                isActive: cameraService.eyeDetected
            )
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.6))
        .cornerRadius(8)
    }

    // MARK: - Eye Guide Overlay
    private func eyeGuideOverlay(size: CGSize) -> some View {
        ZStack {
            // Círculo guia para posicionar o olho
            Circle()
                .stroke(
                    cameraService.eyeDetected ? Color.green : Color.white.opacity(0.5),
                    lineWidth: 2
                )
                .frame(width: size.width * 0.6, height: size.width * 0.6)

            // Linha horizontal de referência (eixo 0°)
            Rectangle()
                .fill(Color.yellow.opacity(0.7))
                .frame(width: size.width * 0.8, height: 1)

            // Marcas de graus
            Text("0°")
                .font(.caption)
                .foregroundColor(.yellow)
                .offset(x: size.width * 0.42)

            Text("180°")
                .font(.caption)
                .foregroundColor(.yellow)
                .offset(x: -size.width * 0.42)

            // Cruz central
            Group {
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 1, height: 40)

                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 1)
            }
        }
    }

    // MARK: - Capture Button
    private var captureButton: some View {
        Button {
            captureReferenceImage()
        } label: {
            ZStack {
                // Anel externo
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 80, height: 80)

                // Botão interno
                Circle()
                    .fill(canCapture ? Color.white : Color.gray)
                    .frame(width: 68, height: 68)

                // Ícone de câmera
                Image(systemName: "camera.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.black)
            }
        }
        .disabled(!canCapture || isCapturing)
        .opacity(canCapture ? 1 : 0.5)
    }

    // MARK: - Helpers
    private var canCapture: Bool {
        motionService.isLeveled && cameraService.eyeDetected
    }

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if !granted {
                    DispatchQueue.main.async {
                        showingPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            showingPermissionAlert = true
        @unknown default:
            break
        }
    }

    private func startCamera() {
        cameraService.setupCamera(useFrontCamera: true) // Câmera frontal para consultório
        cameraService.startSession()
        motionService.startUpdates()
    }

    private func captureReferenceImage() {
        isCapturing = true

        // Feedback háptico
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        cameraService.capturePhoto { image in
            isCapturing = false

            guard let capturedImage = image else {
                return
            }

            // Salvar imagem no caso
            if var currentCase = appState.currentCase {
                currentCase.referenceImageData = capturedImage.jpegData(compressionQuality: 0.8)
                currentCase.referenceImageTimestamp = Date()

                // Salvar landmarks detectados
                currentCase.referenceLandmarks = EyeLandmarks(
                    limbusCenter: CGPointCodable(x: 0.5, y: 0.5), // Placeholder
                    limbusRadius: 0.3,
                    pupilCenter: CGPointCodable(x: 0.5, y: 0.5),
                    pupilRadius: 0.1,
                    limbalVessels: [], // Será processado depois
                    referenceHorizontalAxis: motionService.currentHorizontalAxis,
                    captureQuality: .good
                )

                currentCase.status = .referenceCapured
                appState.currentCase = currentCase
                patientStore.updateCase(currentCase)
            }

            // Navegar para confirmação
            appState.navigationPath.append(AppRoute.referenceConfirmation)
        }
    }
}

// MARK: - Instruction Row
struct InstructionRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.blue)
                .frame(width: 30)

            Text(text)
                .foregroundColor(.white)
        }
    }
}

// MARK: - Status Indicator
struct StatusIndicator: View {
    let icon: String
    let text: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isActive ? .green : .gray)

            Text(text)
                .font(.caption)
                .foregroundColor(isActive ? .white : .gray)
        }
    }
}

// MARK: - Camera Preview View
struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var cameraService: CameraService

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = cameraService.previewLayer {
            previewLayer.frame = uiView.bounds
            if previewLayer.superlayer == nil {
                uiView.layer.addSublayer(previewLayer)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ReferenceCaptureView()
    }
    .environmentObject(AppState())
    .environmentObject(PatientStore())
}
