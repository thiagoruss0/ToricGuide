//
//  LimbalVesselDetector.swift
//  ToricGuide
//
//  Detector de vasos limbares usando Vision Framework
//  Usa edge detection e análise de contornos para identificar padrões vasculares
//

import Vision
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

class LimbalVesselDetector: ObservableObject {

    // MARK: - Published Properties
    @Published var detectedVessels: [DetectedVessel] = []
    @Published var limbusCenter: CGPoint = .zero
    @Published var limbusRadius: CGFloat = 0
    @Published var isProcessing = false
    @Published var lastError: String?

    // MARK: - Private Properties
    private let context = CIContext()
    private var lastProcessedTime: Date = .distantPast
    private let processingInterval: TimeInterval = 0.1 // 10 FPS max

    // Detection parameters
    private var edgeThreshold: Float = 0.3
    private var vesselMinLength: CGFloat = 15
    private var vesselMaxWidth: CGFloat = 8
    private var limbusSearchRadius: CGFloat = 0.4 // Fraction of image size

    // MARK: - Detected Vessel Structure
    struct DetectedVessel: Identifiable {
        let id = UUID()
        let startPoint: CGPoint      // Normalized coordinates (0-1)
        let endPoint: CGPoint        // Normalized coordinates (0-1)
        let angle: Double            // Degrees from center
        let length: CGFloat          // Normalized length
        let thickness: CGFloat       // Estimated thickness
        let confidence: Double       // Detection confidence (0-1)
        let contourPoints: [CGPoint] // Full contour if available

        var midpoint: CGPoint {
            CGPoint(
                x: (startPoint.x + endPoint.x) / 2,
                y: (startPoint.y + endPoint.y) / 2
            )
        }

        var radialDistance: CGFloat {
            // Distance from center (assuming center at 0.5, 0.5)
            let dx = midpoint.x - 0.5
            let dy = midpoint.y - 0.5
            return sqrt(dx * dx + dy * dy)
        }
    }

    // MARK: - Detection Result
    struct DetectionResult {
        let vessels: [DetectedVessel]
        let limbusCenter: CGPoint
        let limbusRadius: CGFloat
        let processingTime: TimeInterval
        let imageSize: CGSize
    }

    // MARK: - Public Methods

    /// Process an image to detect limbal vessels
    func detectVessels(in image: UIImage, completion: @escaping (DetectionResult?) -> Void) {
        // Rate limiting
        let now = Date()
        guard now.timeIntervalSince(lastProcessedTime) >= processingInterval else {
            completion(nil)
            return
        }
        lastProcessedTime = now

        isProcessing = true
        let startTime = Date()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self,
                  let cgImage = image.cgImage else {
                DispatchQueue.main.async {
                    self?.isProcessing = false
                    completion(nil)
                }
                return
            }

            let imageSize = CGSize(width: cgImage.width, height: cgImage.height)

            // Step 1: Detect limbus (iris boundary)
            let (limbusCenter, limbusRadius) = self.detectLimbus(in: cgImage)

            // Step 2: Extract limbal region
            let limbalRegion = self.extractLimbalRegion(
                from: cgImage,
                center: limbusCenter,
                radius: limbusRadius
            )

            // Step 3: Detect vessels in limbal region
            let vessels = self.detectVesselsInRegion(
                limbalRegion,
                originalImage: cgImage,
                limbusCenter: limbusCenter,
                limbusRadius: limbusRadius
            )

            let processingTime = Date().timeIntervalSince(startTime)

            let result = DetectionResult(
                vessels: vessels,
                limbusCenter: limbusCenter,
                limbusRadius: limbusRadius,
                processingTime: processingTime,
                imageSize: imageSize
            )

            DispatchQueue.main.async {
                self.detectedVessels = vessels
                self.limbusCenter = limbusCenter
                self.limbusRadius = limbusRadius
                self.isProcessing = false
                self.lastError = nil
                completion(result)
            }
        }
    }

    /// Process a pixel buffer (for real-time camera feed)
    func detectVessels(in pixelBuffer: CVPixelBuffer, completion: @escaping (DetectionResult?) -> Void) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            completion(nil)
            return
        }

        let uiImage = UIImage(cgImage: cgImage)
        detectVessels(in: uiImage, completion: completion)
    }

    /// Convert detected vessels to EyeLandmarks format
    func convertToLandmarks() -> EyeLandmarks? {
        guard !detectedVessels.isEmpty, limbusRadius > 0 else {
            return nil
        }

        // Convert vessels to landmark vessel descriptors
        let vesselDescriptors = detectedVessels.map { vessel in
            VesselDescriptor(
                angle: vessel.angle,
                normalizedPosition: vessel.midpoint,
                length: vessel.length,
                thickness: vessel.thickness
            )
        }

        return EyeLandmarks(
            pupilCenter: limbusCenter,
            limbusRadius: limbusRadius,
            limbalVessels: vesselDescriptors,
            irisFeatures: [],
            timestamp: Date()
        )
    }

    // MARK: - Private Detection Methods

    /// Detect the limbus (iris boundary) using Vision
    private func detectLimbus(in image: CGImage) -> (center: CGPoint, radius: CGFloat) {
        // Use saliency detection to find the eye region
        let saliencyRequest = VNGenerateAttentionBasedSaliencyImageRequest()

        // Also try face landmarks for eye detection
        let faceLandmarksRequest = VNDetectFaceLandmarksRequest()

        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        do {
            try handler.perform([saliencyRequest, faceLandmarksRequest])

            // Try to get eye position from face landmarks first
            if let faceResults = faceLandmarksRequest.results,
               let face = faceResults.first,
               let landmarks = face.landmarks {

                // Get eye regions
                if let leftEye = landmarks.leftEye,
                   let rightEye = landmarks.rightEye {

                    // Choose the eye with more visible landmarks
                    // For now, use center of detected eyes
                    let leftPoints = leftEye.normalizedPoints
                    let rightPoints = rightEye.normalizedPoints

                    if let leftCenter = calculateCenter(of: leftPoints),
                       let rightCenter = calculateCenter(of: rightPoints) {

                        // Convert to image coordinates
                        let leftImagePoint = CGPoint(
                            x: face.boundingBox.origin.x + leftCenter.x * face.boundingBox.width,
                            y: face.boundingBox.origin.y + leftCenter.y * face.boundingBox.height
                        )
                        let rightImagePoint = CGPoint(
                            x: face.boundingBox.origin.x + rightCenter.x * face.boundingBox.width,
                            y: face.boundingBox.origin.y + rightCenter.y * face.boundingBox.height
                        )

                        // Use the larger/more visible eye
                        let leftRadius = estimateEyeRadius(from: leftPoints, in: face.boundingBox)
                        let rightRadius = estimateEyeRadius(from: rightPoints, in: face.boundingBox)

                        if leftRadius > rightRadius {
                            return (leftImagePoint, leftRadius)
                        } else {
                            return (rightImagePoint, rightRadius)
                        }
                    }
                }
            }

            // Fallback: use saliency to find circular region
            if let saliencyResult = saliencyRequest.results?.first as? VNSaliencyImageObservation {
                if let salientObjects = saliencyResult.salientObjects, !salientObjects.isEmpty {
                    let mainObject = salientObjects[0]
                    let center = CGPoint(
                        x: mainObject.boundingBox.midX,
                        y: mainObject.boundingBox.midY
                    )
                    let radius = min(mainObject.boundingBox.width, mainObject.boundingBox.height) / 2
                    return (center, radius)
                }
            }

        } catch {
            print("[LimbalVesselDetector] Vision error: \(error)")
        }

        // Default: assume centered eye
        return (CGPoint(x: 0.5, y: 0.5), 0.3)
    }

    /// Extract the limbal region around the iris
    private func extractLimbalRegion(from image: CGImage, center: CGPoint, radius: CGFloat) -> CIImage {
        let ciImage = CIImage(cgImage: image)

        // Create a ring mask around the limbus
        let innerRadius = radius * 0.85  // Just inside the limbus
        let outerRadius = radius * 1.25  // Include scleral vessels

        // Apply vignette-like masking
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)

        let centerPixels = CGPoint(
            x: center.x * width,
            y: center.y * height
        )
        let innerRadiusPixels = innerRadius * min(width, height)
        let outerRadiusPixels = outerRadius * min(width, height)

        // Create radial gradient mask
        guard let maskFilter = CIFilter(name: "CIRadialGradient") else {
            return ciImage
        }

        maskFilter.setValue(CIVector(cgPoint: centerPixels), forKey: "inputCenter")
        maskFilter.setValue(innerRadiusPixels, forKey: "inputRadius0")
        maskFilter.setValue(outerRadiusPixels, forKey: "inputRadius1")
        maskFilter.setValue(CIColor.clear, forKey: "inputColor0")
        maskFilter.setValue(CIColor.white, forKey: "inputColor1")

        guard let maskImage = maskFilter.outputImage else {
            return ciImage
        }

        // Apply mask
        guard let blendFilter = CIFilter(name: "CIBlendWithMask") else {
            return ciImage
        }

        blendFilter.setValue(ciImage, forKey: kCIInputImageKey)
        blendFilter.setValue(CIImage(color: .black).cropped(to: ciImage.extent), forKey: kCIInputBackgroundImageKey)
        blendFilter.setValue(maskImage.cropped(to: ciImage.extent), forKey: kCIInputMaskImageKey)

        return blendFilter.outputImage ?? ciImage
    }

    /// Detect vessels in the limbal region using edge detection
    private func detectVesselsInRegion(
        _ region: CIImage,
        originalImage: CGImage,
        limbusCenter: CGPoint,
        limbusRadius: CGFloat
    ) -> [DetectedVessel] {

        var vessels: [DetectedVessel] = []

        // Apply edge detection
        let edgeDetector = CIFilter.cannyEdgeDetector()
        edgeDetector.inputImage = region
        edgeDetector.gaussianSigma = 1.5
        edgeDetector.thresholdLow = Float(edgeThreshold * 0.5)
        edgeDetector.thresholdHigh = edgeThreshold

        guard let edgeImage = edgeDetector.outputImage,
              let edgeCGImage = context.createCGImage(edgeImage, from: edgeImage.extent) else {
            // Fallback to contour detection
            return detectVesselsUsingContours(in: originalImage, center: limbusCenter, radius: limbusRadius)
        }

        // Analyze edge image for linear structures (vessels)
        vessels = analyzeEdgesForVessels(
            edgeCGImage,
            center: limbusCenter,
            radius: limbusRadius,
            imageWidth: CGFloat(originalImage.width),
            imageHeight: CGFloat(originalImage.height)
        )

        // If edge detection didn't find enough vessels, try contour detection
        if vessels.count < 3 {
            let contourVessels = detectVesselsUsingContours(
                in: originalImage,
                center: limbusCenter,
                radius: limbusRadius
            )
            vessels.append(contentsOf: contourVessels)
        }

        // Filter and deduplicate
        vessels = filterAndDeduplicateVessels(vessels)

        return vessels
    }

    /// Detect vessels using VNDetectContoursRequest
    private func detectVesselsUsingContours(
        in image: CGImage,
        center: CGPoint,
        radius: CGFloat
    ) -> [DetectedVessel] {

        var vessels: [DetectedVessel] = []

        let contourRequest = VNDetectContoursRequest()
        contourRequest.contrastAdjustment = 2.0
        contourRequest.detectsDarkOnLight = true
        contourRequest.maximumImageDimension = 512

        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        do {
            try handler.perform([contourRequest])

            guard let result = contourRequest.results?.first else {
                return vessels
            }

            // Process top-level contours
            let contourCount = result.contourCount
            for i in 0..<min(contourCount, 50) {
                if let contour = try? result.contour(at: i) {
                    if let vessel = processContour(contour, center: center, radius: radius) {
                        vessels.append(vessel)
                    }
                }
            }

        } catch {
            print("[LimbalVesselDetector] Contour detection error: \(error)")
        }

        return vessels
    }

    /// Process a single contour to determine if it's a vessel
    private func processContour(_ contour: VNContour, center: CGPoint, radius: CGFloat) -> DetectedVessel? {
        let points = contour.normalizedPoints

        guard points.count >= 3 else { return nil }

        // Calculate contour properties
        let cgPoints = points.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }

        // Find bounding box
        let minX = cgPoints.map { $0.x }.min() ?? 0
        let maxX = cgPoints.map { $0.x }.max() ?? 0
        let minY = cgPoints.map { $0.y }.min() ?? 0
        let maxY = cgPoints.map { $0.y }.max() ?? 0

        let width = maxX - minX
        let height = maxY - minY
        let length = max(width, height)
        let thickness = min(width, height)

        // Filter by size (vessels are elongated)
        let aspectRatio = length / max(thickness, 0.001)
        guard aspectRatio > 2.0 && length > 0.02 && thickness < 0.05 else {
            return nil
        }

        // Check if in limbal region
        let contourCenter = CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
        let distanceFromCenter = hypot(contourCenter.x - center.x, contourCenter.y - center.y)
        let relativeDistance = distanceFromCenter / radius

        // Vessels should be near the limbus (0.8 to 1.3 radius)
        guard relativeDistance > 0.7 && relativeDistance < 1.4 else {
            return nil
        }

        // Calculate angle from center
        let dx = contourCenter.x - center.x
        let dy = contourCenter.y - center.y
        var angle = atan2(dy, dx) * 180 / .pi
        if angle < 0 { angle += 360 }

        // Estimate confidence based on shape and location
        let shapeConfidence = min(aspectRatio / 5.0, 1.0)
        let locationConfidence = 1.0 - abs(relativeDistance - 1.0)
        let confidence = (shapeConfidence + locationConfidence) / 2.0

        // Find endpoints
        let startPoint = cgPoints.first ?? contourCenter
        let endPoint = cgPoints.last ?? contourCenter

        return DetectedVessel(
            startPoint: startPoint,
            endPoint: endPoint,
            angle: angle,
            length: length,
            thickness: thickness,
            confidence: confidence,
            contourPoints: cgPoints
        )
    }

    /// Analyze edge image for vessel-like structures
    private func analyzeEdgesForVessels(
        _ edgeImage: CGImage,
        center: CGPoint,
        radius: CGFloat,
        imageWidth: CGFloat,
        imageHeight: CGFloat
    ) -> [DetectedVessel] {

        var vessels: [DetectedVessel] = []

        // Use Hough line detection concept - scan radially from center
        let numRays = 72  // Every 5 degrees
        let innerRadius = radius * 0.85
        let outerRadius = radius * 1.3

        for i in 0..<numRays {
            let angle = Double(i) * 360.0 / Double(numRays)
            let radians = angle * .pi / 180.0

            // Scan along this ray
            var vesselStart: CGPoint?
            var vesselEnd: CGPoint?
            var maxIntensity: CGFloat = 0

            for r in stride(from: innerRadius, to: outerRadius, by: 0.01) {
                let x = center.x + CGFloat(cos(radians)) * r
                let y = center.y + CGFloat(sin(radians)) * r

                // Check if in bounds
                guard x >= 0 && x <= 1 && y >= 0 && y <= 1 else { continue }

                // Sample edge intensity (simplified - would need actual pixel sampling)
                let intensity = sampleEdgeIntensity(at: CGPoint(x: x, y: y), in: edgeImage)

                if intensity > edgeThreshold {
                    if vesselStart == nil {
                        vesselStart = CGPoint(x: x, y: y)
                    }
                    vesselEnd = CGPoint(x: x, y: y)
                    maxIntensity = max(maxIntensity, intensity)
                }
            }

            // If we found a vessel segment
            if let start = vesselStart, let end = vesselEnd {
                let length = hypot(end.x - start.x, end.y - start.y)

                if length > 0.02 {  // Minimum length threshold
                    let vessel = DetectedVessel(
                        startPoint: start,
                        endPoint: end,
                        angle: angle,
                        length: length,
                        thickness: 0.01,  // Estimate
                        confidence: Double(maxIntensity),
                        contourPoints: [start, end]
                    )
                    vessels.append(vessel)
                }
            }
        }

        return vessels
    }

    /// Sample edge intensity at a point (simplified)
    private func sampleEdgeIntensity(at point: CGPoint, in image: CGImage) -> CGFloat {
        let x = Int(point.x * CGFloat(image.width))
        let y = Int(point.y * CGFloat(image.height))

        guard x >= 0 && x < image.width && y >= 0 && y < image.height else {
            return 0
        }

        // Create a 1x1 context to sample the pixel
        guard let context = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return 0
        }

        context.draw(image, in: CGRect(x: -x, y: -y, width: image.width, height: image.height))

        guard let data = context.data else { return 0 }

        let pixel = data.assumingMemoryBound(to: UInt8.self)
        let intensity = CGFloat(pixel[0]) / 255.0  // Red channel

        return intensity
    }

    /// Filter and deduplicate vessels
    private func filterAndDeduplicateVessels(_ vessels: [DetectedVessel]) -> [DetectedVessel] {
        var filtered: [DetectedVessel] = []

        for vessel in vessels.sorted(by: { $0.confidence > $1.confidence }) {
            // Check if similar vessel already exists
            let isDuplicate = filtered.contains { existing in
                let angleDiff = abs(vessel.angle - existing.angle)
                let normalizedDiff = min(angleDiff, 360 - angleDiff)
                let distanceDiff = hypot(
                    vessel.midpoint.x - existing.midpoint.x,
                    vessel.midpoint.y - existing.midpoint.y
                )
                return normalizedDiff < 10 && distanceDiff < 0.05
            }

            if !isDuplicate && vessel.confidence > 0.3 {
                filtered.append(vessel)
            }
        }

        // Keep top vessels
        return Array(filtered.prefix(15))
    }

    // MARK: - Helper Methods

    private func calculateCenter(of points: [CGPoint]) -> CGPoint? {
        guard !points.isEmpty else { return nil }
        let sumX = points.reduce(0) { $0 + $1.x }
        let sumY = points.reduce(0) { $0 + $1.y }
        return CGPoint(x: sumX / CGFloat(points.count), y: sumY / CGFloat(points.count))
    }

    private func estimateEyeRadius(from points: [CGPoint], in boundingBox: CGRect) -> CGFloat {
        guard points.count >= 2 else { return 0.1 }

        // Estimate based on eye landmark spread
        let xs = points.map { $0.x }
        let ys = points.map { $0.y }

        let width = ((xs.max() ?? 0) - (xs.min() ?? 0)) * boundingBox.width
        let height = ((ys.max() ?? 0) - (ys.min() ?? 0)) * boundingBox.height

        return max(width, height) / 2
    }

    // MARK: - Configuration

    func setDetectionParameters(
        edgeThreshold: Float = 0.3,
        vesselMinLength: CGFloat = 15,
        vesselMaxWidth: CGFloat = 8
    ) {
        self.edgeThreshold = edgeThreshold
        self.vesselMinLength = vesselMinLength
        self.vesselMaxWidth = vesselMaxWidth
    }
}
