import SwiftUI

public struct SurveyContainerView: View {
    @Bindable public var viewModel: SurveyViewModel
    public var onFinished: (() -> Void)? = nil

    @State private var showingCamera = false
    @State private var showingCancelAlert = false

    public init(viewModel: SurveyViewModel, onFinished: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.onFinished = onFinished
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isExpired {
                    ExpiredSurveyView()
                } else if viewModel.submissionCompleted {
                    SurveyCompletedView()
                } else {
                    surveyContent
                }
            }
            .navigationTitle(viewModel.currentTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .topBarTrailing) {
                        TimerBadgeView(remainingSeconds: viewModel.remainingSeconds)
                    }
                    .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        TimerBadgeView(remainingSeconds: viewModel.remainingSeconds)
                    }
                }
            }
            .alert("Exit Survey?", isPresented: $showingCancelAlert) {
                Button("Keep Answering", role: .cancel) {}
                Button("Exit", role: .destructive) {
                    onFinished?()
                }
            } message: {
                Text("Your progress on this prompt will not be submitted.")
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraCaptureView { captured in
                viewModel.capturedImage = captured
            }
        }
    }

    private var surveyContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Adaptive Researcher Dialogue Banner or Initial Survey Description
                if viewModel.isFollowUpRound, let researcherMessage = viewModel.researcherMessage {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "text.bubble.fill")
                            .font(.title2)
                            .foregroundColor(AppTheme.navy)
                            .padding(.top, 2)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Researcher Note")
                                .font(.caption.bold())
                                .foregroundColor(AppTheme.navy)
                                .textCase(.uppercase)

                            Text(researcherMessage)
                                .font(.subheadline)
                                .foregroundColor(AppTheme.navy)
                                .lineSpacing(2)
                        }

                        Spacer()
                    }
                    .padding()
                    .background(AppTheme.gold.opacity(0.15))
                    .cornerRadius(12)
                    .padding(.horizontal)
                } else if let desc = viewModel.survey.description {
                    Text(desc)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }

                // Dynamic questions: renders initial survey or active follow-up questions
                ForEach(viewModel.currentQuestions) { question in
                    let isVisible = viewModel.gatingVisibilityMap[question.questionId] ?? (question.gatingRule == nil)
                    if isVisible {
                        questionView(for: question)
                            .padding(.horizontal)
                    }
                }

                // Photo capture card (Phase 1 intake only)
                if !viewModel.isFollowUpRound {
                    PhotoPreviewCard(
                        image: viewModel.capturedImage?.previewImage,
                        onTapCapture: { showingCamera = true },
                        onTapRemove: { viewModel.capturedImage = nil }
                    )
                    .padding(.horizontal)
                }

                // Error message banner
                if let err = viewModel.errorMessage {
                    Text(err)
                        .font(.footnote.bold())
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal)
                }

                // Submit button (Fixed size with spinner centered inside)
                Button(action: { Task { await viewModel.submitResponse() } }) {
                    HStack {
                        if viewModel.isSubmitting {
                            ProgressView()
                                .tint(AppTheme.pureWhite)
                        } else {
                            Text(viewModel.isFollowUpRound ? "Complete Follow-up" : "Submit Survey")
                                .font(.headline)
                                .foregroundColor(AppTheme.pureWhite)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
                .background(AppTheme.navy)
                .cornerRadius(12)
                .padding(.horizontal)
                .disabled(viewModel.isSubmitting)
            }
            .padding(.vertical)
            .id(viewModel.activeFollowUp?.roundNumber ?? 0)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
        )
    }

    @ViewBuilder
    private func questionView(for q: Question) -> some View {
        switch q.type {
        case .ratingScale:
            RatingScaleQuestionView(question: q, answer: binding(for: q.questionId))
        case .singleChoice:
            SingleChoiceQuestionView(question: q, answer: binding(for: q.questionId))
        case .multipleChoice:
            MultipleChoiceQuestionView(question: q, answer: binding(for: q.questionId))
        case .text:
            TextQuestionView(
                question: q,
                answer: binding(for: q.questionId),
                onTextChanged: { text in
                    viewModel.handleTextChanged(questionId: q.questionId, newText: text)
                },
                onBlur: { text in
                    viewModel.handleTextFieldBlur(questionId: q.questionId, currentText: text)
                },
                gatingScoreInfo: viewModel.gatingScores[q.questionId]
            )
        case .numeric:
            NumericQuestionView(question: q, answer: binding(for: q.questionId))
        }
    }

    private func binding(for id: String) -> Binding<AnyCodableValue?> {
        Binding(
            get: { viewModel.answers[id] },
            set: { val in
                viewModel.recordInteraction()
                if let val = val {
                    viewModel.answers[id] = val
                } else {
                    viewModel.answers.removeValue(forKey: id)
                }
            }
        )
    }
}
