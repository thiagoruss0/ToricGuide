//
//  ToricGuideApp.swift
//  ToricGuide
//
//  Aplicativo para guiar implantação de lentes tóricas
//  Compatível com iPhone 11 + MicroRec + Zeiss Opmi Lumera I
//
//  CEDOA © 2025
//

import SwiftUI

@main
struct ToricGuideApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var patientStore = PatientStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(patientStore)
                .preferredColorScheme(.light) // Cirurgia requer boa visibilidade
        }
    }
}

// MARK: - Estado Global do App
class AppState: ObservableObject {
    @Published var currentPatient: Patient?
    @Published var currentCase: SurgicalCase?
    @Published var navigationPath = NavigationPath()

    // Configurações do MicroRec
    @Published var microRecCalibrated: Bool = false
    @Published var cameraZoomLevel: CGFloat = 1.0

    func startNewCase() {
        currentPatient = nil
        currentCase = nil
    }

    func resetNavigation() {
        navigationPath = NavigationPath()
    }
}
