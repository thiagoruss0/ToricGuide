# ToricGuide

**Guia de Navegação para Implantação de Lentes Tóricas**

Aplicativo iOS para guiar cirurgiões oftalmologistas na implantação de lentes intraoculares tóricas durante cirurgia de catarata.

![iOS](https://img.shields.io/badge/iOS-15.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-Proprietary-red)

## Sobre

O ToricGuide é um aplicativo desenvolvido para iPhone que funciona de forma similar ao sistema VERION da Alcon, permitindo:

- Captura de imagem de referência do olho com paciente sentado
- Detecção de landmarks oculares (limbo, pupila, vasos limbares)
- Cálculo do eixo de implantação da LIO tórica
- Guia cirúrgico em tempo real com detecção de ciclotorção
- Overlay do eixo alvo sobre imagem do microscópio

### Compatibilidade

- **Dispositivo**: iPhone 11 ou superior
- **Adaptador**: MicroRec (Custom Surgical)
- **Microscópio**: Zeiss Opmi Lumera I
- **iOS**: 15.0+

## Fluxo do Aplicativo

```
CONSULTÓRIO                          CENTRO CIRÚRGICO
(Paciente Sentado)                   (Paciente Supino)

┌──────────────┐                    ┌──────────────┐
│ 1. Cadastro  │                    │ 5. Guia      │
│    Paciente  │                    │    Cirúrgico │
└──────┬───────┘                    └──────▲───────┘
       │                                   │
       ▼                                   │
┌──────────────┐                           │
│ 2. CAPTURA   │ ◄── Landmarks:            │
│    REFERÊNCIA│     - Vasos limbares      │
│    (SENTADO) │     - Padrão da íris      │
└──────┬───────┘     - Eixo horizontal     │
       │              (giroscópio)         │
       ▼                                   │
┌──────────────┐                           │
│ 3. Dados     │                           │
│    Biométricos│                          │
│    + LIO     │                           │
└──────┬───────┘                           │
       │                                   │
       ▼                                   │
┌──────────────┐    ┌──────────────┐       │
│ 4. Cálculo   │───►│  Comparação  │───────┘
│    do Eixo   │    │  Ref vs Live │
└──────────────┘    │  = Ciclotorção│
                    └──────────────┘
```

## Estrutura do Projeto

```
ToricGuide/
├── App/
│   ├── ToricGuideApp.swift      # Entry point
│   └── ContentView.swift         # Navigation
├── Models/
│   ├── Patient.swift             # Dados do paciente
│   ├── SurgicalCase.swift        # Caso cirúrgico
│   ├── Keratometry.swift         # Dados de ceratometria
│   └── ToricIOL.swift            # Catálogo de LIOs
├── Views/
│   ├── Home/
│   ├── PatientRegistration/
│   ├── ReferenceCapture/
│   ├── BiometricData/
│   ├── Results/
│   ├── SurgicalGuide/
│   └── Settings/
├── Services/
│   ├── Camera/
│   │   ├── CameraService.swift   # Captura de vídeo
│   │   └── MotionService.swift   # Giroscópio
│   ├── Vision/
│   │   └── EyeDetectionService.swift  # Detecção de olho
│   ├── Calculation/
│   │   └── ToricCalculator.swift # Cálculos tóricos
│   └── Storage/
│       └── PatientStore.swift    # Persistência
├── Utils/
│   └── Extensions.swift          # Extensões úteis
└── Resources/
    └── Info.plist                # Configurações
```

## LIOs Suportadas

| Fabricante | Modelo | Plataforma | Cilindros |
|------------|--------|------------|-----------|
| Alcon | AcrySof IQ Toric | SN6AT | T3-T9 |
| Alcon | Clareon Toric | CNWTT | T3-T9 |
| J&J Vision | Tecnis Toric II | ZCT | 100-400 |
| Zeiss | AT TORBI 709M | 709M | T10-T120 |
| Bausch+Lomb | enVista Toric | MX60T | T1-T7 |

## Tecnologias Utilizadas

- **SwiftUI** - Interface do usuário
- **AVFoundation** - Captura de câmera
- **Vision Framework** - Detecção facial/olhos
- **Core Motion** - Giroscópio/Acelerômetro
- **Core ML** - Processamento de imagem (futuro)

## Funcionalidades Principais

### 1. Captura de Referência
- Usa câmera frontal do iPhone
- Verifica nivelamento com giroscópio
- Detecta estruturas oculares automaticamente
- Registra eixo horizontal de referência

### 2. Cálculo Vetorial
- Análise de astigmatismo corneano
- Consideração do SIA (Surgically Induced Astigmatism)
- Recomendação automática de LIO
- Previsão de astigmatismo residual

### 3. Guia Intraoperatório
- Overlay em tempo real do eixo alvo
- Detecção automática de ciclotorção
- Correção dinâmica do eixo
- Ajuste manual fino (±1°)
- Travamento do eixo

## Instalação

1. Clone o repositório
2. Abra `ToricGuide.xcodeproj` no Xcode 15+
3. Configure o Bundle Identifier
4. Execute no dispositivo físico (necessário para câmera)

## Permissões Necessárias

- **Câmera**: Captura de imagens e guia cirúrgico
- **Motion**: Nivelamento do dispositivo
- **Fotos**: Salvar capturas de tela (opcional)

## Considerações Clínicas

⚠️ **AVISO IMPORTANTE**

Este aplicativo é uma ferramenta de auxílio e não substitui o julgamento clínico do cirurgião. O usuário é responsável por:

- Verificar os dados inseridos
- Confirmar o cálculo do eixo
- Validar o alinhamento final da LIO
- Seguir as boas práticas cirúrgicas

## Roadmap

- [ ] Integração com CoreML para detecção avançada de vasos
- [ ] Suporte a mais modelos de LIO
- [ ] Exportação de relatórios em PDF
- [ ] Sincronização com nuvem
- [ ] Integração com biômetros via Bluetooth

## Licença

Proprietary - CEDOA © 2025

## Contato

Para suporte ou dúvidas, entre em contato com a equipe de desenvolvimento.
