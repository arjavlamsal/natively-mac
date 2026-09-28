import SwiftUI
import NativelyCore

/// Fast model picker popover adhering to macOS HIG with native materials and semantic badges.
public struct ModelSelectorPopoverView: View {
    @ObservedObject public var viewModel: OverlayViewModel
    
    public init(viewModel: OverlayViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI REASONING MODEL")
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            
            VStack(spacing: 3) {
                ForEach(viewModel.availableModels) { model in
                    let isSelected = model.id == viewModel.currentModel.id
                    
                    Button(action: {
                        viewModel.currentModel = model
                        viewModel.isModelSelectorPresented = false
                    }) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(isSelected ? NativelyTheme.purpleAccent : Color.secondary.opacity(0.3))
                                .frame(width: 6, height: 6)
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(model.name)
                                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium))
                                    .foregroundColor(isSelected ? .white : .primary)
                                Text(model.provider)
                                    .font(.system(size: 9.5))
                                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                            }
                            
                            Spacer()
                            
                            if model.isFast {
                                Text("⚡ FAST")
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundColor(NativelyTheme.emeraldGreen)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(NativelyTheme.emeraldGreen.opacity(0.14))
                                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                            }
                            
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(isSelected ? .white : NativelyTheme.purpleAccent)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(isSelected ? Color.accentColor : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .frame(width: 220)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
