//
//  HomeView.swift
//  ToricGuide
//
//  Tela principal do aplicativo
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var patientStore: PatientStore

    var body: some View {
        ZStack {
            // Fundo gradiente sutil
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGray6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerSection

                Spacer()

                // Botões principais
                mainButtonsSection

                Spacer()

                // Footer
                footerSection
            }
            .padding()
        }
        .navigationBarHidden(true)
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(spacing: 8) {
            // Logo/Ícone
            Image(systemName: "eye.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.top, 40)

            Text("ToricGuide")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text("Guia de Implantação de Lentes Tóricas")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Botões Principais
    private var mainButtonsSection: some View {
        VStack(spacing: 16) {
            // Nova Cirurgia
            HomeButton(
                icon: "camera.fill",
                title: "NOVA CIRURGIA",
                subtitle: "Iniciar novo caso cirúrgico",
                color: .blue
            ) {
                appState.startNewCase()
                appState.navigationPath.append(AppRoute.patientRegistration)
            }

            // Casos Salvos
            HomeButton(
                icon: "folder.fill",
                title: "CASOS SALVOS",
                subtitle: "\(patientStore.totalCases) casos registrados",
                color: .green
            ) {
                appState.navigationPath.append(AppRoute.savedCases)
            }

            // Configurações
            HomeButton(
                icon: "gearshape.fill",
                title: "CONFIGURAÇÕES",
                subtitle: "Calibração e preferências",
                color: .gray
            ) {
                appState.navigationPath.append(AppRoute.settings)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Footer
    private var footerSection: some View {
        VStack(spacing: 4) {
            Text("ToricGuide v1.0")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("CEDOA © 2025")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.bottom, 20)
    }
}

// MARK: - Botão da Home
struct HomeButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Ícone
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.15))
                        .frame(width: 50, height: 50)

                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(color)
                }

                // Textos
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Seta
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: .black.opacity(isPressed ? 0.05 : 0.1),
                        radius: isPressed ? 2 : 8,
                        y: isPressed ? 1 : 4
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.15)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Preview
#Preview {
    HomeView()
        .environmentObject(AppState())
        .environmentObject(PatientStore.preview)
}
