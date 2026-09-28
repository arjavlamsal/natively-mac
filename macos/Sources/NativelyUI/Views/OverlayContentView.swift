import SwiftUI
import AppKit

/// Unified top-level overlay SwiftUI view hosting the TopPillBar, LiveTranscript, and AIResponseCard.
public struct OverlayContentView: View {
    @ObservedObject public var viewModel: OverlayViewModel
    public var onCropTrigger: () -> Void = {}
    public var onWindowDrag: (CGSize) -> Void = { _ in }
    
    public init(
        viewModel: OverlayViewModel,
        onCropTrigger: @escaping () -> Void = {},
        onWindowDrag: @escaping (CGSize) -> Void = { _ in }
    ) {
        self.viewModel = viewModel
        self.onCropTrigger = onCropTrigger
        self.onWindowDrag = onWindowDrag
    }
    
    public var body: some View {
        VStack(spacing: 8) {
            // Top Pill Bar with drag gesture
            TopPillBarView(viewModel: viewModel, onCropTrigger: onCropTrigger)
                .gesture(
                    DragGesture(minimumDistance: 1, coordinateSpace: .global)
                        .onChanged { gesture in
                            onWindowDrag(gesture.translation)
                        }
                )
            
            // Expanded Content (Diarized Transcript + AI Card)
            if viewModel.isExpanded {
                VStack(spacing: 8) {
                    if !viewModel.transcripts.isEmpty || viewModel.isAudioActive {
                        LiveTranscriptView(turns: viewModel.transcripts)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    AIResponseCardView(viewModel: viewModel)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(8)
        .frame(width: 480)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.black.opacity(viewModel.isExpanded ? 0.35 : 0.0))
                .background(.ultraThinMaterial.opacity(viewModel.isExpanded ? 0.8 : 0.0))
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.82), value: viewModel.isExpanded)
    }
}
