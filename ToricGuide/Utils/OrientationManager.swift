//
//  OrientationManager.swift
//  ToricGuide
//
//  Gerenciador de orientação do dispositivo
//  Força landscape nas telas que usam câmera traseira (MicroRec)
//

import SwiftUI
import UIKit

// MARK: - Orientation Manager
class OrientationManager: ObservableObject {
    static let shared = OrientationManager()

    @Published var currentOrientation: UIDeviceOrientation = .portrait
    @Published var isLandscape: Bool = false

    private init() {
        updateOrientation()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(orientationChanged),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
    }

    @objc private func orientationChanged() {
        updateOrientation()
    }

    private func updateOrientation() {
        let orientation = UIDevice.current.orientation
        currentOrientation = orientation
        isLandscape = orientation.isLandscape
    }

    /// Força uma orientação específica
    func lockOrientation(_ orientation: UIInterfaceOrientationMask) {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientation))
        }
    }

    /// Força landscape
    func forceLandscape() {
        lockOrientation(.landscape)
    }

    /// Força portrait
    func forcePortrait() {
        lockOrientation(.portrait)
    }

    /// Libera todas as orientações
    func unlockOrientation() {
        lockOrientation(.all)
    }
}

// MARK: - Orientation Lock Modifier
struct OrientationLockModifier: ViewModifier {
    let orientation: UIInterfaceOrientationMask

    func body(content: Content) -> some View {
        content
            .onAppear {
                OrientationManager.shared.lockOrientation(orientation)
            }
            .onDisappear {
                OrientationManager.shared.unlockOrientation()
            }
    }
}

extension View {
    /// Força uma orientação específica enquanto esta view está visível
    func lockOrientation(_ orientation: UIInterfaceOrientationMask) -> some View {
        modifier(OrientationLockModifier(orientation: orientation))
    }

    /// Força landscape enquanto esta view está visível
    func forceLandscape() -> some View {
        lockOrientation(.landscape)
    }

    /// Força portrait enquanto esta view está visível
    func forcePortrait() -> some View {
        lockOrientation(.portrait)
    }
}

// MARK: - Adaptive Layout Helper
struct AdaptiveLayout {
    let isLandscape: Bool
    let screenSize: CGSize

    var isCompact: Bool {
        screenSize.height < 400
    }

    var safeAreaInsets: EdgeInsets {
        // Estimativa de safe area em landscape
        if isLandscape {
            return EdgeInsets(top: 0, leading: 44, bottom: 0, trailing: 44)
        }
        return EdgeInsets(top: 44, leading: 0, bottom: 34, trailing: 0)
    }

    // Tamanhos adaptativos
    var buttonHeight: CGFloat {
        isCompact ? 44 : 50
    }

    var fontSize: CGFloat {
        isCompact ? 14 : 16
    }

    var padding: CGFloat {
        isCompact ? 8 : 16
    }

    var iconSize: CGFloat {
        isCompact ? 20 : 28
    }
}

// MARK: - Landscape Aware View
struct LandscapeAwareView<Content: View>: View {
    @StateObject private var orientationManager = OrientationManager.shared
    let content: (AdaptiveLayout) -> Content

    init(@ViewBuilder content: @escaping (AdaptiveLayout) -> Content) {
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = AdaptiveLayout(
                isLandscape: geometry.size.width > geometry.size.height,
                screenSize: geometry.size
            )
            content(layout)
        }
    }
}
