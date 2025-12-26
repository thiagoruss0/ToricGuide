//
//  Extensions.swift
//  ToricGuide
//
//  Extensões úteis para o aplicativo
//

import SwiftUI
import UIKit

// MARK: - Color Extensions
extension Color {
    static let toricBlue = Color(red: 0.2, green: 0.5, blue: 0.9)
    static let toricGreen = Color(red: 0.2, green: 0.8, blue: 0.4)
    static let toricOrange = Color(red: 0.95, green: 0.6, blue: 0.2)
    static let toricPurple = Color(red: 0.6, green: 0.3, blue: 0.8)

    static let surgicalBackground = Color.black
    static let surgicalOverlay = Color.white.opacity(0.8)
}

// MARK: - View Extensions
extension View {
    /// Aplica estilo de cartão
    func cardStyle() -> some View {
        self
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    /// Aplica estilo de botão primário
    func primaryButtonStyle() -> some View {
        self
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(12)
    }

    /// Aplica estilo de botão secundário
    func secondaryButtonStyle() -> some View {
        self
            .font(.headline)
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray5))
            .cornerRadius(12)
    }

    /// Previne que a tela apague durante uso cirúrgico
    func keepScreenOn(_ keepOn: Bool = true) -> some View {
        self.onAppear {
            UIApplication.shared.isIdleTimerDisabled = keepOn
        }.onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}

// MARK: - Double Extensions
extension Double {
    /// Formata como graus
    var asDegrees: String {
        String(format: "%.1f°", self)
    }

    /// Formata como dioptrias
    var asDiopters: String {
        String(format: "%.2f D", self)
    }

    /// Normaliza ângulo para 0-180
    var normalizedAxis: Double {
        var normalized = self.truncatingRemainder(dividingBy: 180)
        if normalized < 0 {
            normalized += 180
        }
        return normalized
    }

    /// Normaliza ângulo para 0-360
    var normalizedAngle: Double {
        var normalized = self.truncatingRemainder(dividingBy: 360)
        if normalized < 0 {
            normalized += 360
        }
        return normalized
    }
}

// MARK: - Date Extensions
extension Date {
    var formattedBR: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: self)
    }

    var formattedWithTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy HH:mm"
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: self)
    }
}

// MARK: - UIImage Extensions
extension UIImage {
    /// Redimensiona imagem mantendo proporção
    func resized(to targetSize: CGSize) -> UIImage {
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let ratio = min(widthRatio, heightRatio)

        let newSize = CGSize(
            width: size.width * ratio,
            height: size.height * ratio
        )

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// Rotaciona imagem
    func rotated(by degrees: Double) -> UIImage {
        let radians = CGFloat(degrees * .pi / 180)

        var newSize = CGRect(origin: .zero, size: size)
            .applying(CGAffineTransform(rotationAngle: radians))
            .integral.size

        newSize.width = abs(newSize.width)
        newSize.height = abs(newSize.height)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { context in
            let origin = CGPoint(x: newSize.width / 2, y: newSize.height / 2)
            context.cgContext.translateBy(x: origin.x, y: origin.y)
            context.cgContext.rotate(by: radians)
            self.draw(at: CGPoint(x: -size.width / 2, y: -size.height / 2))
        }
    }
}

// MARK: - Haptic Feedback
struct HapticFeedback {
    static func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    static func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    static func heavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }

    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
}

// MARK: - CGPoint Extensions
extension CGPoint {
    /// Distância entre dois pontos
    func distance(to point: CGPoint) -> CGFloat {
        sqrt(pow(x - point.x, 2) + pow(y - point.y, 2))
    }

    /// Ângulo em graus de um ponto em relação a outro
    func angle(to point: CGPoint) -> Double {
        let dx = point.x - x
        let dy = point.y - y
        var angle = atan2(dy, dx) * 180 / .pi
        if angle < 0 {
            angle += 360
        }
        return angle
    }
}
