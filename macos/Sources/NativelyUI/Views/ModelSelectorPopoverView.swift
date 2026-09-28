import SwiftUI
import NativelyCore

/// Fast model picker popover matching Natively's model dropdown in the overlay.
public struct ModelSelectorPopoverView: View {
    @ObservedObject public var viewModel: OverlayViewModel
    
    public init(viewModel: OverlayViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SELECT MODEL")
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.45))
                .padding(.horizontal, 4)
            
            VStack(spacing: 3) {
                ForEach(viewModel.availableModels) { model in
                    Button(action: {
                        viewModel.currentModel = model
                        viewModel.isModelSelectorPresented = false
                    }) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(model.id == viewModel.currentModel.id ? Color.purple : Color.white.opacity(0.15))
                                .frame(width: 6, height: 6)
                            
                            VStack(alignment: .leading, spacing: 1) {
                                Text(model.name)
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundColor(model.id == viewModel.currentModel.id ? Color.white : Color.white.opacity(0.8))
                                Text(model.provider)
                                    .font(.system(size: 9))
                                    .foregroundColor(Color.white.opacity(0.45))
                            }
                            
                            Spacer()
                            
                            if model.isFast {
                                Text("⚡ FAST")
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color.green)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.green.opacity(0.12))
                                    .cornerRadius(3)
                            }
                            
                            if model.id == viewModel.currentModel.id {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color.purple)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(model.id == viewModel.currentModel.id ? Color.white.opacity(0.08) : Color.clear)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .frame(width: 220)
        .background(Color(red: 0.11, green: 0.13, blue: 0.17))
    }
}
