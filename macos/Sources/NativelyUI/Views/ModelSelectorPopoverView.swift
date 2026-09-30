import SwiftUI
import NativelyCore

/// Fast model picker popover adhering to macOS HIG with native materials and semantic badges.
public struct ModelSelectorPopoverView: View {
    @ObservedObject public var viewModel: OverlayViewModel
    
    public init(viewModel: OverlayViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow
            
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 4) {
                    ForEach(viewModel.availableModels) { model in
                        modelRow(for: model)
                    }
                }
                .padding(.vertical, 1)
            }
            .frame(maxHeight: 340)
        }
        .padding(12)
        .frame(width: 310)
        .background(NativelyTheme.bgSecondary)
    }
    
    private var headerRow: some View {
        HStack {
            Text("AI REASONING MODEL")
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .foregroundColor(NativelyTheme.textTertiary)
            
            Spacer()
            
            Text("\(viewModel.availableModels.count) AVAILABLE")
                .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                .foregroundColor(NativelyTheme.textTertiary)
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }
    
    private func modelRow(for model: AIModelInfo) -> some View {
        let isSelected = model.id == viewModel.currentModel.id
        
        return Button(action: {
            viewModel.currentModel = model
            viewModel.currentProviderName = model.name
            viewModel.isModelSelectorPresented = false
        }) {
            HStack(spacing: 9) {
                Circle()
                    .fill(isSelected ? NativelyTheme.purpleAccent : Color.white.opacity(0.18))
                    .frame(width: 6.5, height: 6.5)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(model.name)
                            .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium))
                            .foregroundColor(isSelected ? .white : NativelyTheme.textPrimary)
                        
                        Text(model.provider)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(isSelected ? .white.opacity(0.85) : NativelyTheme.textSecondary)
                            .padding(.horizontal, 4.5)
                            .padding(.vertical, 1)
                            .background(Color.white.opacity(isSelected ? 0.2 : 0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    }
                    
                    if !model.subtitle.isEmpty {
                        Text(model.subtitle)
                            .font(.system(size: 9))
                            .foregroundColor(isSelected ? .white.opacity(0.8) : NativelyTheme.textTertiary)
                            .lineLimit(1)
                    }
                }
                
                Spacer(minLength: 4)
                
                if model.isFast {
                    Text("⚡ FAST")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(NativelyTheme.emeraldGreen)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1.5)
                        .background(NativelyTheme.emeraldGreen.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                }
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(isSelected ? .white : NativelyTheme.purpleAccent)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? NativelyTheme.purpleAccent.opacity(0.85) : Color.white.opacity(0.03))
            )
        }
        .buttonStyle(.plain)
    }
}
