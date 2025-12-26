//
//  ContentView.swift
//  ToricGuide
//
//  View principal com navegação
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack(path: $appState.navigationPath) {
            HomeView()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .patientRegistration:
                        PatientRegistrationView()
                    case .referenceCapture:
                        ReferenceCaptureView()
                    case .referenceConfirmation:
                        ReferenceConfirmationView()
                    case .biometricData:
                        BiometricDataView()
                    case .results:
                        ResultsView()
                    case .surgicalGuide:
                        SurgicalGuideView()
                    case .savedCases:
                        SavedCasesView()
                    case .settings:
                        SettingsView()
                    case .microRecCapture:
                        MicroRecCaptureView()
                    }
                }
        }
    }
}

// MARK: - Rotas de Navegação
enum AppRoute: Hashable {
    case patientRegistration
    case referenceCapture
    case referenceConfirmation
    case biometricData
    case results
    case surgicalGuide
    case savedCases
    case settings
    case microRecCapture
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(PatientStore())
}
