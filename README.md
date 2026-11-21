# Simple Surveys iOS Client

[![Platform](https://img.shields.io/badge/Platform-iOS%2017.0%2B-blue.svg?style=flat-square&logo=apple)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg?style=flat-square&logo=swift)](https://swift.org)
[![UI Framework](https://img.shields.io/badge/UI-SwiftUI-purple.svg?style=flat-square&logo=swift)](https://developer.apple.com/xcode/swiftui/)
[![ML Engine](https://img.shields.io/badge/Inference-ONNX%20Runtime%20Mobile-green.svg?style=flat-square&logo=onnx)](https://onnxruntime.ai)
[![Architecture](https://img.shields.io/badge/Architecture-MVVM%20%2B%20Repository-teal.svg?style=flat-square)](#architecture--data-flow)
[![License](https://img.shields.io/badge/License-MIT-lightgrey.svg?style=flat-square)](#license)

A high-performance, native iOS client built with **Swift** and **SwiftUI** for rigorous **Experience Sampling Method (ESM)** and **Ecological Momentary Assessment (EMA)** research studies. 

The client features **zero-latency on-device Natural Language Inference (NLI) question gating** powered by a quantized OpenJev model executed via **ONNX Runtime Mobile**, **adaptive multi-round LLM follow-up orchestration**, **independent freeze/restart survey timers**, **tamper-evident self-describing response logging**, **multimodal camera capture**, and **privacy-first anonymous telemetry**.

---

## Table of Contents

- [Overview & Research Paradigm](#overview--research-paradigm)
- [Core Features & Innovations](#core-features--innovations)
  - [1. On-Device Semantic Question Gating (OpenJev via ONNX Runtime)](#1-on-device-semantic-question-gating-openjev-via-onnx-runtime)
  - [2. Adaptive Multi-Round Surveys & Independent Timers](#2-adaptive-multi-round-surveys--independent-timers)
  - [3. Self-Describing Auditable Responses](#3-self-describing-auditable-responses)
  - [4. Anonymous ESM & Push Notification Triggering](#4-anonymous-esm--push-notification-triggering)
  - [5. Multimodal Camera & Geolocation Capture](#5-multimodal-camera--geolocation-capture)
- [Architecture & Data Flow](#architecture--data-flow)
  - [System Architecture Flowchart](#system-architecture-flowchart)
  - [Survey Intake & Submission Sequence](#survey-intake--submission-sequence)
- [Xcode Project Layout & Directory Structure](#xcode-project-layout--directory-structure)
- [Getting Started & Setup](#getting-started--setup)
  - [Prerequisites](#prerequisites)
  - [Framework & Model Setup](#framework--model-setup)
  - [Opening and Running the Project](#opening-and-running-the-project)
  - [Simulating Push Notifications in Development](#simulating-push-notifications-in-development)
- [Configuration & Environment](#configuration--environment)
  - [API Endpoints & Network Base URL](#api-endpoints--network-base-url)
  - [Permissions & Info.plist Configurations](#permissions--infoplist-configurations)
  - [Push Notification Capabilities](#push-notification-capabilities)
- [On-Device OpenJev Technical Specification](#on-device-openjev-technical-specification)
  - [Inference Mechanics & Tensor Pipeline](#inference-mechanics--tensor-pipeline)
  - [SentencePiece Metaspace Tokenizer](#sentencepiece-metaspace-tokenizer)
  - [Hypothesis Normalization & Predicate Mapping](#hypothesis-normalization--predicate-mapping)
  - [Fail-Closed Safety Architecture & Timeout Guards](#fail-closed-safety-architecture--timeout-guards)
  - [Hardware Benchmark Targets](#hardware-benchmark-targets)
- [API Contract & Integration](#api-contract--integration)
  - [1. Device Registration (`POST /api/notifications/devices`)](#1-device-registration-post-apinotificationsdevices)
  - [2. Fetch Survey Schema (`GET /api/surveys/{id}`)](#2-fetch-survey-schema-get-apisurveysid)
  - [3. Submit Survey Response (`POST /api/responses`)](#3-submit-survey-response-post-apiresponses)
- [Contributing](#contributing)
- [License](#license)

---

## Overview & Research Paradigm

Traditional mobile survey and Experience Sampling Method (ESM) platforms suffer from two fundamental engineering trade-offs:

1. **Rigid Branching vs. Network Latency**: Branching logic based on free-form participant text historically required streaming responses to a remote cloud server or LLM endpoint, introducing unacceptable network latency (500ms–2500ms), offline failure modes, and severe participant privacy exposure.
2. **Artificial Time Penalties in Multi-Round Flows**: When adaptive LLMs synthesize personalized follow-up rounds server-side, the participant is often unfairly penalized by countdown timers that run during network transfer and generation.

The **Simple Surveys iOS Client** resolves these challenges by coupling a **schema-driven SwiftUI dynamic rendering pipeline** with a **100% local, on-device quantized SentencePiece NLI transformer (`openjev_classifier_int8.onnx`)** executed directly on Apple Silicon CPU via `onnxruntime.xcframework`. Dynamic question gates evaluate locally in **10ms–25ms**, keeping participant keystrokes entirely on-device while providing immediate fluid animations.

---

## Core Features & Innovations

### 1. On-Device Semantic Question Gating (OpenJev via ONNX Runtime)

```
[ Participant Types: "I feel exhausted and swamped" ]
                         │
                         ▼
        ┌──────────────────────────────────┐
        │  Typing Inactivity Delay (600ms) │  ◄── Cancels prior task on keystroke
        └──────────────────────────────────┘
                         │
                         ▼
        ┌──────────────────────────────────┐
        │       Input Quality Guards       │  ◄── Requires ≥ 3 complete words
        │ (Word Boundary & Punctuation)    │  ◄── Appends terminal "." if omitted
        └──────────────────────────────────┘
                         │
                         ▼
        ┌──────────────────────────────────┐
        │ SentencePiece Metaspace Tokenize │  ◄── [CLS] premise [SEP] hypothesis [SEP]
        └──────────────────────────────────┘
                         │
                         ▼
        ┌──────────────────────────────────┐
        │ ONNX Runtime Mobile C-API (INT8) │  ◄── ~14ms CPU execution
        └──────────────────────────────────┘
                         │
                         ▼
        ┌──────────────────────────────────┐
        │ Softmax: P(Entailment) >= 0.55?  │  ◄── Threshold comparison
        └──────────────────────────────────┘
                         │
             ┌───────────┴───────────┐
             ▼                       ▼
      [ TRUE: Reveal ]       [ FALSE: Hide ]
```

- **100% On-Device CPU Inference**: Executes `openjev_classifier_int8.onnx` directly using the low-overhead C-API of `onnxruntime.xcframework`. Eliminates remote round-trips for dynamic mid-survey branching and functions completely offline in air-gapped environments.
- **Typing Inactivity Delay (500ms–750ms Debounced Evaluation)**: Evaluates input only after the participant pauses typing (default: 600ms). When typing words like *"I feel great"*, intermediate fragments like *"I feel GREA"* no longer trigger false-positive subword activations or erratic UI flickering.
- **Input Quality Guards**:
  - **Minimum Word Count**: Requires at least 3 whitespace-separated tokens before triggering neural inference, preventing single-word false triggers on words like *"I"*, *"No"*, or *"Maybe"*.
  - **Field Blur Immediate Evaluation**: Tapping outside the text editor or dismissing the keyboard automatically bypasses the debounce pause and evaluates immediately.
  - **Pre-Submission Instant Barrier Check**: When the participant taps "Submit", all gate conditions re-evaluate synchronously against current inputs. If a condition evaluates to `true`, submission is temporarily halted to reveal the dependent question and prevent accidental skipping.
- **Terminal Punctuation Normalization**: Transformer NLI models are highly sensitive to sentence boundary markers. Unpunctuated user drafts have a terminal period (`.`) appended prior to tokenization, ensuring consistent NLI end-of-sequence attention pooling without modifying the user's raw input.
- **Strict Fail-Closed Privacy & Resilience**: If the model asset is missing, tokenization fails, or inference exceeds a strict 200ms frame budget timeout, the gate safely defaults to hidden (`false`) without crashing or exposing unvalidated views.

### 2. Adaptive Multi-Round Surveys & Independent Timers

- **Seamless Follow-Up Transition**: When `POST /api/responses` returns an HTTP 201 receipt with a populated `followup_survey` payload, the client transitions seamlessly to the adaptive round within the same modal session, rendering the personalized `researcher_message` banner and follow-up questions using the identical generic SwiftUI component.
- **Independent Timer Lifecycle**:
  - **Submit-Time Clock Freeze**: The countdown timer stops immediately the instant "Submit" is pressed, stamping `completed_at = Date()`. Network delays, cell tower retries, and server-side LLM inference times never penalize the participant.
  - **Brand New Follow-Up Window**: Upon presenting the follow-up round, the countdown timer resets to a brand new 5-minute window, and `roundPresentedAt` is mapped to `notification_sent_at` for strict, independent compliance auditing.
  - **Optional Early Skip**: Participants can gracefully exit follow-up rounds via a "Skip & Complete" action without invalidating or losing their primary survey submission.

### 3. Self-Describing Auditable Responses

- **Always-Attached `question_prompt`**: Every `QuestionAnswer` item submitted across both initial and follow-up rounds packages `question_id`, non-empty `question_prompt`, and type-erased `value`.
- **Historical Immutability**: Survey datasets remain fully auditable and self-describing even if researchers modify survey questions or prompt phrasing in the backend database at a later date.

### 4. Anonymous ESM & Push Notification Triggering

- **Privacy-First Participant Device Registration**: Registers device tokens with `POST /api/notifications/devices` alongside timezone metadata (`DeviceRegistration`), requiring zero personally identifiable information (PII), phone numbers, or account credentials.
- **Local & APNs Deep Linking**: Handles remote APNs notifications (`remote-notification` background mode) and local simulator payloads via `scripts/ping_notification.sh` to prompt users exactly when study sample windows open.

### 5. Multimodal Camera & Geolocation Capture

- **Integrated Camera Service**: Native `AVFoundation` photo capture card (`CameraCaptureView`, `PhotoPreviewCard`) with automatic aspect ratio scaling and JPEG compression (0.8 quality, max 1920px bounds) for contextual environmental snapshots.
- **Contextual Geolocation**: Thread-safe `CoreLocation` coordinate capture (`LocationService`) tagging responses with latitude, longitude, and horizontal accuracy at the time of intake.

---

## Architecture & Data Flow

The client follows modern **Clean Architecture** and **MVVM (Model-View-ViewModel)** with SwiftUI and Swift Concurrency (`async`/`await`, `actor`, and the `@Observable` macro).

### System Architecture Flowchart

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                             SwiftUI View Layer                              │
│                                                                             │
│  ┌───────────────────────┐  ┌───────────────────────┐  ┌─────────────────┐  │
│  │  SurveyContainerView  │  │   DynamicSurveyView   │  │ CameraCapture   │  │
│  │   (TimerBadgeView)    │  │  (Question Widgets)   │  │ & PhotoPreview  │  │
│  └───────────┬───────────┘  └───────────┬───────────┘  └────────┬────────┘  │
└──────────────┼──────────────────────────┼───────────────────────┼───────────┘
               │                          │                       │
               ▼                          ▼                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ViewModel Layer (@Observable Macro)                      │
│                                                                             │
│                            SurveyViewModel                                  │
│   • Answers Dict: [questionId: AnyCodableValue]                             │
│   • Visibility Map: [questionId: Bool]                                      │
│   • Countdown Timer: Independent 5-min Task (Freeze on Submit)              │
│   • Inactivity Delay: 600ms Task Debounce                                   │
└──────────────────────┬───────────────────────────────┬──────────────────────┘
                       │                               │
                       ▼                               ▼
┌──────────────────────────────────────┐  ┌───────────────────────────────────┐
│     On-Device Gating Subsystem       │  │     Data & Network Services       │
│                                      │  │                                   │
│       OnDeviceGatingService          │  │       SurveyRepository            │
│       (Thread-Safe Actor)            │  │       APIClient (URLSession)      │
│  ┌────────────────────────────────┐  │  │                                   │
│  │ Metaspace SentencePiece Token  │  │  │  • GET  /api/surveys/{id}         │
│  │ tokenizer.json Greedy Subwords │  │  │  • POST /api/responses (Multipart)│
│  └───────────────┬────────────────┘  │  │  • POST /api/notifications/devices│
│                  ▼                   │  └─────────────────┬─────────────────┘
│  ┌────────────────────────────────┐  │                    │
│  │     onnxruntime.xcframework    │  │                    │
│  │  (openjev_classifier_int8)     │  │                    │
│  │   Input: [1, SeqLen] Int64     │  │                    │
│  │   Output: [1, 3] Softmax Logits│  │                    │
│  └────────────────────────────────┘  │                    │
└──────────────────────────────────────┘                    │
                                                            ▼
                                          ┌───────────────────────────────────┐
                                          │      FastAPI Backend & LLM        │
                                          │     (POST /api/responses)         │
                                          └───────────────────────────────────┘
```

### Survey Intake & Submission Sequence

```mermaid
sequenceDiagram
    autonumber
    actor Participant as Study Participant
    participant View as DynamicSurveyView (SwiftUI)
    participant VM as SurveyViewModel (@Observable)
    participant Gating as OnDeviceGatingService (Actor)
    participant Net as SurveyRepository & APIClient
    participant Server as FastAPI Backend + Ollama LLM

    Note over Participant, View: Phase 1: Intake & On-Device Gating
    View->>VM: startTimer(durationMinutes: 5)
    Participant->>View: Types free-text response ("I feel swamped and stressed")
    View->>VM: handleTextChanged(questionId, newText)
    Note over VM: Cancel prior task; wait 600ms typing inactivity
    VM->>Gating: evaluateRuleWithScore(rule, answer)
    Gating->>Gating: Normalize punctuation + SentencePiece Tokenize
    Gating->>Gating: ONNX Runtime CPU inference (~14ms)
    Gating-->>VM: GatingEvaluationScore(matched: true, score: 0.88)
    VM-->>View: withAnimation { gatingVisibilityMap[q_dependent] = true }
    View->>Participant: Dependent question smoothly animates into view

    Note over Participant, Net: Phase 2: Submission & Clock Freeze
    Participant->>View: Taps "Submit"
    View->>VM: submitInitialSurvey()
    Note over VM: FREEZE TIMER IMMEDIATELY: stopTimer()<br/>Stamps completed_at = Date()
    VM->>VM: preSubmissionGateCheck()
    VM->>Net: submitResponse(submission, imageData)
    Net->>Server: POST /api/responses (Multipart / JSON)
    Server-->>Net: HTTP 201 Created (SurveySubmissionReceipt)
    Net-->>VM: Receipt with followup_survey payload

    alt Follow-Up Survey Received (followup_survey != nil)
        Note over Participant, View: Phase 3: Fresh Follow-Up Window
        VM->>VM: transitionToFollowUpRound(followup)
        Note over VM: START BRAND NEW 5-MIN TIMER<br/>notification_sent_at = roundPresentedAt
        VM-->>View: Re-render DynamicSurveyView with researcher_message & follow-up questions
        Participant->>View: Answers follow-up and taps "Submit"
        View->>VM: submitFollowUpSurvey()
        Note over VM: FREEZE TIMER AGAIN: stopTimer()<br/>Stamps followupCompletedAt = Date()
        VM->>Net: submitResponse(followupSubmission, parentResponseId)
        Net->>Server: POST /api/responses
        Server-->>Net: HTTP 201 Created (followup_survey: nil)
        Net-->>VM: Final completion receipt
        VM-->>View: Render SurveyCompletedView
    else Single Round Survey (followup_survey == nil)
        VM-->>View: Render SurveyCompletedView
    end
```

---

## Xcode Project Layout & Directory Structure

The repository is organized following modular architectural boundaries:

```
Simple-Surveys-iOS/
├── Simple-Surveys-iOS.xcodeproj/             # Xcode project configuration
├── scripts/
│   └── ping_notification.sh                 # Simulator push notification test harness
└── Simple-Surveys-iOS/
    ├── App/
    │   ├── AppConfiguration.swift           # Base URL, timeouts, and image constants
    │   ├── AppDelegate.swift                # APNs remote notification delegates
    │   ├── SimpleSurveysApp.swift           # Application entry point & Root View
    │   └── Theme.swift                      # Colors, typography, and card stylings
    ├── Frameworks/
    │   └── onnxruntime.xcframework/         # Embedded Microsoft ONNX Runtime C/C++ runtime
    ├── Models/
    │   ├── AnyCodableValue.swift            # Type-erased dynamic Codable value wrapper
    │   ├── DeviceRegistration.swift         # APNs device token registration models
    │   ├── LocationData.swift               # Geographic coordinate DTOs
    │   ├── NotificationConfig.swift         # Push and local schedule models
    │   ├── Question.swift                   # Question, GatingRule, and Validation rules
    │   ├── SurveyConfig.swift               # Root Survey definition schemas
    │   └── SurveyResponse.swift             # Response submission & follow-up receipt DTOs
    ├── Repositories/
    │   ├── SurveyRepository.swift           # Survey fetch & multipart submission coordination
    │   └── SurveyRepositoryProtocol.swift   # Protocol abstraction for mocking
    ├── Resources/
    │   ├── Assets.xcassets                  # App icons, accent colors, and imagery
    │   ├── Info.plist                       # Permissions (Camera, Location, APNs)
    │   ├── openjev_classifier_int8.onnx     # Quantized SentencePiece NLI ONNX model (~18MB)
    │   └── tokenizer.json                   # Subword vocabulary and metaspace mappings
    ├── Services/
    │   ├── Camera/
    │   │   ├── CameraService.swift          # AVFoundation photo capture implementation
    │   │   └── CameraServiceProtocol.swift  # Camera abstraction protocol
    │   ├── Gating/
    │   │   ├── GatingProfiler.swift         # Microsecond inference benchmark logger
    │   │   ├── OnDeviceGatingService.swift  # Thread-safe actor running ONNX & tokenizer
    │   │   └── OnDeviceGatingServiceProtocol.swift
    │   ├── Location/
    │   │   ├── LocationService.swift        # CoreLocation GPS coordinate provider
    │   │   └── LocationServiceProtocol.swift
    │   ├── Network/
    │   │   ├── APIClient.swift              # URLSession HTTP client with error handling
    │   │   ├── APIClientProtocol.swift      # Network abstraction protocol
    │   │   └── APIEndpoint.swift            # REST endpoint enum definitions
    │   ├── Notifications/
    │   │   ├── NotificationService.swift    # UserNotifications & APNs coordinator
    │   │   └── NotificationServiceProtocol.swift
    │   └── Permissions/
    │       ├── PermissionManager.swift      # Camera and location authorization coordinator
    │       └── PermissionManagerProtocol.swift
    ├── ViewModels/
    │   ├── CameraViewModel.swift            # Shutter state and photo preview lifecycle
    │   ├── HomeViewModel.swift              # Survey availability and study status
    │   ├── OnboardingViewModel.swift        # Consent and permission grants
    │   └── SurveyViewModel.swift            # Core survey engine: gating, timers, submission
    └── Views/
        ├── Camera/
        │   ├── CameraCaptureView.swift      # Full-screen AVFoundation camera feed
        │   └── PhotoPreviewCard.swift       # Retake / confirm snapshot card
        ├── Common/
        │   ├── ErrorBannerView.swift        # Toast error notifications
        │   └── LoadingView.swift            # Shimmer & progress indicators
        ├── Home/
        │   ├── ExpirationBannerView.swift   # Time window alert banner
        │   └── HomeView.swift               # Active prompts & manual test triggers
        ├── Onboarding/
        │   ├── LegalSheetView.swift         # Modal consent reader
        │   ├── OnboardingView.swift         # Initial consent & onboarding flow
        │   ├── PermissionRevokedView.swift  # Settings recovery screen
        │   ├── PrivacyPolicyView.swift      # Privacy policy text view
        │   └── TermsAndConditionsView.swift # Terms & conditions text view
        ├── Questions/
        │   ├── MultipleChoiceQuestionView.swift # Multi-select checkbox chips
        │   ├── NumericQuestionView.swift    # Validated numeric input pad
        │   ├── RatingScaleQuestionView.swift# 1–5 or 1–7 Likert scale row
        │   ├── SingleChoiceQuestionView.swift   # Radio button options
        │   └── TextQuestionView.swift       # Free-text editor with debounce trigger
        └── Survey/
            ├── DynamicSurveyView.swift      # Dynamic schema-driven question renderer
            ├── ExpiredSurveyView.swift      # Expired window notice
            ├── SurveyCompletedView.swift    # Thank you / submission confirmed card
            ├── SurveyContainerView.swift    # Survey host with header, timer, and footer
            └── TimerBadgeView.swift         # Dynamic ticking countdown badge
```

---

## Getting Started & Setup

### Prerequisites

| Component | Minimum Requirement | Recommended |
|---|---|---|
| **macOS** | macOS 14.0 Sonoma | macOS 15.0 Sequoia |
| **Xcode** | Xcode 15.0 | Xcode 16.0+ |
| **Swift Toolchain** | Swift 5.9 | Swift 6.0 |
| **Deployment Target** | iOS 17.0 | iOS 17.0+ |
| **Target Hardware** | Apple Silicon (M-Series Mac) | Apple Silicon for high-speed build & test |

### Framework & Model Setup

After a fresh clone of the repository, set up the required native binary framework and bundled model assets before building:

1. **Download ONNX Runtime Framework**:
   * Download the official iOS release package from Microsoft's ONNX GitHub repository:
     `https://github.com/microsoft/onnxruntime/releases/download/v1.18.0/onnxruntime-c-1.18.0-ios.zip`
   * Unzip the downloaded file.

2. **Place in Project Directory**:
   * Create a `Frameworks/` folder in the root of the project target (if it does not already exist):
     ```bash
     mkdir -p Simple-Surveys-iOS/Frameworks
     ```
   * Move the unzipped `onnxruntime.xcframework` folder into the `Frameworks/` directory so the path is:
     `Simple-Surveys-iOS/Frameworks/onnxruntime.xcframework`

3. **Verify in Xcode**:
   * Open `Simple-Surveys-iOS.xcodeproj` in Xcode.
   * Select the **Simple-Surveys-iOS** target $\rightarrow$ **General** tab.
   * Under **Frameworks, Libraries, and Embedded Content**, verify that `onnxruntime.xcframework` is present.
   * Ensure its Embed setting is configured to **"Embed & Sign"**.

4. **Verify Resources**:
   * Confirm that the OpenJev model (`openjev_classifier_int8.onnx`) and tokenizer file (`tokenizer.json`) inside `Simple-Surveys-iOS/Resources/` are present in the target's **Build Phases $\rightarrow$ Copy Bundle Resources**.

### Opening and Running the Project

1. **Clone the repository**:
   ```bash
   git clone https://github.com/Villanova-Software-Engineers/Simple-Surveys-iOS.git
   cd Simple-Surveys-iOS
   ```

2. **Set up the Framework & Model assets** (follow the [Framework & Model Setup](#framework--model-setup) steps above).

3. **Open the project in Xcode**:
   ```bash
   open Simple-Surveys-iOS.xcodeproj
   ```

4. **Select a Run Destination**:
   - Choose any iOS 17+ Simulator (e.g., `iPhone 16 Pro` or `iPhone 15 Pro`).
   - Or connect a physical iOS device provisioned with your Apple Developer Team profile.

5. **Build and Run**:
   - Press `Cmd + R` or select **Product > Run**.

### Simulating Push Notifications in Development

Because the iOS Simulator cannot connect to Apple Push Notification service (APNs) servers directly, a test harness script is provided to simulate incoming ESM survey prompts via `xcrun simctl push`:

```bash
# Make the helper script executable
chmod +x scripts/ping_notification.sh

# Ping the booted simulator with a default ESM prompt
./scripts/ping_notification.sh

# Or ping with a custom title, message, and target survey_id
./scripts/ping_notification.sh "Afternoon Check-In 🔔" "How are you feeling right now?" "daily_wellbeing_adaptive"
```

The script crafts an Apple-compliant APNs payload, locates the active simulator, and delivers the banner notification directly to the SpringBoard.

---

## Configuration & Environment

### API Endpoints & Network Base URL

Application environment endpoints are configured in `AppConfiguration.swift`:

```swift
public enum AppConfiguration {
    /// Base URL for the Simple Surveys backend API
    public static var apiBaseURL: URL {
        #if targetEnvironment(simulator)
        return URL(string: "http://127.0.0.1:8000")!
        #else
        // Replace with your local machine's LAN IP when testing on physical hardware
        return URL(string: "http://192.168.1.150:8000")!
        #endif
    }
    
    public static let requestTimeout: TimeInterval = 30.0
    public static let defaultTimeToCompleteMinutes: Int = 5
    public static let maxImageDimension: CGFloat = 1920.0
    public static let imageCompressionQuality: CGFloat = 0.8
}
```

> [!TIP]
> When testing on a physical iPhone connected to the same Wi-Fi network as your backend development server, update the `#else` branch with your development machine's local IP address (e.g. `http://192.168.X.X:8000`).

### Permissions & Info.plist Configurations

The application requires specific privacy justification strings configured in `Simple-Surveys-iOS/Resources/Info.plist`:

| Key | Description / Usage Prompt |
|---|---|
| `NSCameraUsageDescription` | *"Simple Surveys needs camera access to allow you to photograph your immediate surroundings during scheduled survey prompts."* |
| `NSLocationWhenInUseUsageDescription` | *"Simple Surveys requires your approximate location when submitting survey responses to pair spatial context with study observations."* |
| `NSAppTransportSecurity` | Configured with `NSAllowsLocalNetworking: true` and `NSAllowsArbitraryLoads: true` for development over local HTTP servers. |

### Push Notification Capabilities

Under the app target's **Signing & Capabilities**:
- **Push Notifications**: Configured to register with APNs and receive remote payloads.
- **Background Modes**: Configured with `remote-notification` to allow background wake-up and schedule syncing.

---

## On-Device OpenJev Technical Specification

### Inference Mechanics & Tensor Pipeline

Semantic question gating operates through a local **Natural Language Inference (NLI)** zero-shot classification formulation:
- **Premise**: The participant's typed answer text.
- **Hypothesis**: A structured predicate synthesized from the survey's `natural_language_condition`.

```
Premise:    "I have three exams this week and feel completely swamped."
Hypothesis: "The person feels stress or pressure."
```

The model produces a logit vector corresponding to three classes:
$$\mathbf{z} = \begin{bmatrix} z_{\text{contradiction}} \\ z_{\text{entailment}} \\ z_{\text{neutral}} \end{bmatrix}$$

A numerically stable softmax is computed on-device:
$$P(\text{entailment}) = \frac{e^{z_{\text{entailment}} - z_{\max}}}{\sum_{i} e^{z_i - z_{\max}}}$$

If $P(\text{entailment}) \ge \text{threshold}$ (default: `0.55`), the gated question is dynamically revealed.

### SentencePiece Metaspace Tokenizer

The tokenizer loads `tokenizer.json` from the application bundle and executes an in-memory Metaspace subword decomposition:
1. Replaces whitespace with the Unicode metaspace symbol `\u{2581}` (`_`).
2. Performs longest-prefix matching against the embedded 30,522-entry vocabulary dictionary.
3. Packages tensors in BERT format:
   - `input_ids`: `[1] + premise_tokens + [2] + hypothesis_tokens + [2]` (`[CLS]=1`, `[SEP]=2`).
   - `attention_mask`: Vector of ones with matching sequence length.

### Hypothesis Normalization & Predicate Mapping

To ensure high zero-shot transfer without requiring survey authors to hand-craft formal NLI hypothesis strings, `OnDeviceGatingService.swift` normalizes condition strings into declarative hypotheses:

| Raw Condition in Survey Config | Normalized NLI Hypothesis Evaluated by Model |
|---|---|
| `"stress"` / `"anxiety"` / `"overwhelm"` | `"The person feels stress or pressure."` |
| `"response expresses fatigue"` | `"The person feels fatigue."` |
| `"participant mentions weather"` | `"The person mentions weather."` |
| `"exhausted"` | `"The person feels exhausted."` |

### Fail-Closed Safety Architecture & Timeout Guards

To guarantee that the user experience is never degraded by edge cases, `OnDeviceGatingService` implements a strict **Fail-Closed** policy:
1. **Model Missing / Not Loaded**: Evaluates immediately to `false`.
2. **Short Word Count (< 3 words)**: Returns `false` without executing neural inference.
3. **Execution Timeout**: Uses Swift's `withThrowingTaskGroup` with a strict **200ms timeout budget**. If CPU scheduling is constrained, the task cancels and safely returns `false`.
4. **Exception Handling**: Any tensor allocation failure or unmapped token defaults to `false`.

### Hardware Benchmark Targets

Benchmarked on Apple Silicon A-Series and M-Series processors:

| Chip Architecture | Representative Devices | Typical CPU Latency | Memory Footprint | UI Budget Status |
|---|---|---|---|---|
| **A17 Pro / A18 / A18 Pro** | iPhone 15 Pro, 16, 16 Pro | **8ms – 15ms** | ~48 MB | Sub-frame; zero stutter |
| **A15 / A16 Bionic** | iPhone 13, 14, 15 | **14ms – 22ms** | ~52 MB | Fluid background Task |
| **A12 / A13 / A14 Bionic** | iPhone XR, 11, 12 | **25ms – 40ms** | ~55 MB | Asynchronous off MainActor |

---

## API Contract & Integration

The iOS client communicates with the backend REST API via `APIClient.swift` and `SurveyRepository.swift`.

### 1. Device Registration (`POST /api/notifications/devices`)

Transmits the APNs device token upon initial consent:

```swift
public struct DeviceRegistration: Codable, Sendable {
    public let deviceToken: String
    public let platform: DevicePlatform // .ios
    public let timezone: String         // e.g. "America/New_York"
    public let registeredAt: Date
}
```

```json
{
  "device_token": "740f4707bebcf74f9b7c25d48e3358945f6aa01da5ddb387462c7eaf61bb78ad",
  "platform": "ios",
  "timezone": "America/New_York",
  "registered_at": "2026-11-21T06:00:00.000Z"
}
```

### 2. Fetch Survey Schema (`GET /api/surveys/{id}`)

Retrieves survey questions, validation constraints, and gating rules:

```swift
public struct QuestionConfig: Codable, Identifiable, Sendable {
    public let questionId: String
    public let prompt: String
    public let type: QuestionType // rating_scale, single_choice, multiple_choice, text, numeric
    public let isRequired: Bool
    public let validationRules: ValidationRules?
    public let gatingRule: QuestionGatingRule?
}

public struct QuestionGatingRule: Codable, Sendable {
    public let sourceQuestionId: String
    public let `operator`: GatingOperator // openjev_matches, equals, contains, greater_than, less_than
    public let naturalLanguageCondition: String?
    public let threshold: Double
}
```

```json
{
  "survey_id": "daily_wellbeing_adaptive",
  "title": "Daily Pulse & Context Survey",
  "description": "Momentary assessment of workload, affect, and physical context.",
  "questions": [
    {
      "question_id": "q1_mood",
      "prompt": "How are you feeling right now?",
      "type": "text",
      "is_required": true,
      "validation_rules": {
        "placeholder": "Describe your current mental state...",
        "min_length": 3
      },
      "gating_rule": null
    },
    {
      "question_id": "q2_stress_source",
      "prompt": "What specific deadline or stressor is occupying your attention?",
      "type": "text",
      "is_required": true,
      "validation_rules": null,
      "gating_rule": {
        "source_question_id": "q1_mood",
        "operator": "openjev_matches",
        "natural_language_condition": "response expresses stress, pressure, or anxiety",
        "threshold": 0.55
      }
    }
  ],
  "adaptive_followup": {
    "enabled": true,
    "max_questions_per_round": 2,
    "max_followup_rounds": 1
  }
}
```

### 3. Submit Survey Response (`POST /api/responses`)

Submits participant answers alongside geolocation and an optional contextual photo as `multipart/form-data`:

```swift
public struct SurveyResponseSubmission: Codable, Sendable {
    public let responseId: String?
    public let surveyId: String
    public let notificationSentAt: Date?
    public let startedAt: Date
    public let completedAt: Date
    public let location: LocationData?
    public let answers: [QuestionAnswer]
    public let parentResponseId: String?
    public let researcherMessage: String?
}

public struct QuestionAnswer: Codable, Sendable {
    public let questionId: String
    public let questionPrompt: String
    public let value: AnyCodableValue
}
```

#### Ingress Payload (`submission_data` JSON Part):
```json
{
  "survey_id": "daily_wellbeing_adaptive",
  "notification_sent_at": "2026-11-21T06:00:00.000Z",
  "started_at": "2026-11-21T06:01:10.000Z",
  "completed_at": "2026-11-21T06:02:45.000Z",
  "location": {
    "latitude": 40.0371,
    "longitude": -75.3436,
    "accuracy_meters": 5.0
  },
  "answers": [
    {
      "question_id": "q1_mood",
      "question_prompt": "How are you feeling right now?",
      "value": "I feel very overwhelmed and stressed about finals."
    },
    {
      "question_id": "q2_stress_source",
      "question_prompt": "What specific deadline or stressor is occupying your attention?",
      "value": "My operating systems project due tomorrow morning."
    }
  ],
  "parent_response_id": null,
  "researcher_message": null
}
```

#### Egress Receipt (`SurveySubmissionReceipt`):
```json
{
  "response_id": "resp_9c2b4d8a",
  "survey_id": "daily_wellbeing_adaptive",
  "status": "COMPLETED",
  "status_message": "Survey submitted successfully.",
  "image_stored": true,
  "image_filename": "2026-11-21T06-02-45_resp_9c2b4d8a.jpg",
  "received_at": "2026-11-21T06:02:46.120Z",
  "followup_survey": {
    "parent_response_id": "resp_9c2b4d8a",
    "survey_id": "daily_wellbeing_adaptive",
    "round_number": 1,
    "title": "Follow-Up Check-In",
    "researcher_message": "You mentioned feeling overwhelmed about finals. Have you had an opportunity to take a restorative break today?",
    "questions": [
      {
        "question_id": "followup_break_taken",
        "prompt": "Did you step away from your study area in the past 2 hours?",
        "type": "single_choice",
        "is_required": true,
        "validation_rules": {
          "options": ["Yes, took a walk", "Yes, took a meal break", "No, studied continuously"]
        },
        "gating_rule": null
      }
    ]
  }
}
```

---

## Contributing

1. Fork the repository and create a feature branch (`git checkout -b feature/gating-enhancement`).
2. Verify all models build cleanly in Xcode without warnings.
3. Run microbenchmarks on physical Apple Silicon hardware via `GatingProfiler.swift`.
4. Submit a descriptive Pull Request referencing the associated issue.

---

## License

This project is licensed under the **MIT License**. See the `LICENSE` file for details.
