//
//  CameraService.swift
//  ToricGuide
//
//  Serviço de câmera para captura de imagens
//

import AVFoundation
import UIKit
import Vision

class CameraService: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isRunning = false
    @Published var previewLayer: AVCaptureVideoPreviewLayer?
    @Published var capturedImage: UIImage?
    @Published var eyeDetected = false
    @Published var eyePosition: CGPoint = .zero
    @Published var eyeBounds: CGRect = .zero

    // MARK: - Private Properties
    private let captureSession = AVCaptureSession()
    private var videoOutput = AVCaptureVideoDataOutput()
    private var photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")

    // Vision request for eye detection
    private var faceDetectionRequest: VNDetectFaceLandmarksRequest?

    // Completion handler for photo capture
    private var photoCaptureCompletion: ((UIImage?) -> Void)?

    // Camera position
    var usingFrontCamera = true

    // MARK: - Initialization
    override init() {
        super.init()
        setupVision()
    }

    // MARK: - Setup Vision
    private func setupVision() {
        faceDetectionRequest = VNDetectFaceLandmarksRequest { [weak self] request, error in
            guard let self = self,
                  let results = request.results as? [VNFaceObservation],
                  let face = results.first else {
                DispatchQueue.main.async {
                    self?.eyeDetected = false
                }
                return
            }

            DispatchQueue.main.async {
                self.eyeDetected = true
                self.processFaceObservation(face)
            }
        }
    }

    private func processFaceObservation(_ face: VNFaceObservation) {
        // Obter posição do olho
        if let landmarks = face.landmarks {
            // Para OD (direito do paciente = esquerdo na imagem)
            // Para OE (esquerdo do paciente = direito na imagem)
            if let leftEye = landmarks.leftEye {
                let eyePoints = leftEye.normalizedPoints
                if let center = eyePoints.first {
                    // Converter coordenadas normalizadas
                    let x = face.boundingBox.origin.x + center.x * face.boundingBox.width
                    let y = face.boundingBox.origin.y + center.y * face.boundingBox.height
                    self.eyePosition = CGPoint(x: x, y: y)
                }
            }
        }

        self.eyeBounds = face.boundingBox
    }

    // MARK: - Setup Camera
    func setupCamera(useFrontCamera: Bool = true) {
        self.usingFrontCamera = useFrontCamera

        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .high

            // Remove existing inputs
            for input in self.captureSession.inputs {
                self.captureSession.removeInput(input)
            }

            // Add camera input
            let cameraPosition: AVCaptureDevice.Position = useFrontCamera ? .front : .back

            guard let camera = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: cameraPosition
            ) else {
                print("Camera not available")
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: camera)
                if self.captureSession.canAddInput(input) {
                    self.captureSession.addInput(input)
                }
            } catch {
                print("Error setting up camera: \(error)")
                return
            }

            // Setup video output for frame analysis
            self.videoOutput.setSampleBufferDelegate(self, queue: self.sessionQueue)
            if self.captureSession.canAddOutput(self.videoOutput) {
                self.captureSession.addOutput(self.videoOutput)
            }

            // Setup photo output
            if self.captureSession.canAddOutput(self.photoOutput) {
                self.captureSession.addOutput(self.photoOutput)
            }

            self.captureSession.commitConfiguration()

            // Create preview layer
            DispatchQueue.main.async {
                let previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
                previewLayer.videoGravity = .resizeAspectFill
                self.previewLayer = previewLayer
            }
        }
    }

    // MARK: - Start/Stop
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.captureSession.isRunning else { return }
            self.captureSession.startRunning()
            DispatchQueue.main.async {
                self.isRunning = true
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.captureSession.isRunning else { return }
            self.captureSession.stopRunning()
            DispatchQueue.main.async {
                self.isRunning = false
            }
        }
    }

    // MARK: - Capture Photo
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        self.photoCaptureCompletion = completion

        let settings = AVCapturePhotoSettings()
        settings.flashMode = .off
        settings.isHighResolutionPhotoEnabled = true

        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    // MARK: - Switch Camera
    func switchCamera() {
        usingFrontCamera.toggle()
        setupCamera(useFrontCamera: usingFrontCamera)
    }
}

// MARK: - Video Output Delegate
extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let request = faceDetectionRequest else {
            return
        }

        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .up,
            options: [:]
        )

        try? handler.perform([request])
    }
}

// MARK: - Photo Capture Delegate
extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil,
              let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            photoCaptureCompletion?(nil)
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.capturedImage = image
            self?.photoCaptureCompletion?(image)
        }
    }
}
