import SwiftUI
import NativelySecurity

/// Settings sheet for API keys, companion server configuration, and modes.
public struct SettingsSheetView: View {
    @ObservedObject public var viewModel: LauncherViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab = 0
    @State private var isTokenCopied = false
    
    public init(viewModel: LauncherViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
            
            Divider()
                .background(Color.white.opacity(0.1))
            
            // Tab Picker
            Picker("", selection: $selectedTab) {
                Text("AI Keys").tag(0)
                Text("Companion & Web").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(14)
            
            // Tab Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if selectedTab == 0 {
                        apiKeysSection
                    } else {
                        companionSection
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 520, height: 460)
        .background(Color(red: 0.10, green: 0.11, blue: 0.15))
    }
    
    private var apiKeysSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("API KEYS (STORED IN MACOS KEYCHAIN)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.5))
            
            keyField(
                label: "Anthropic Claude",
                placeholder: "sk-ant-...",
                value: $viewModel.anthropicKey,
                keyName: "anthropic_api_key"
            )
            
            keyField(
                label: "OpenAI GPT-4o",
                placeholder: "sk-proj-...",
                value: $viewModel.openAIKey,
                keyName: "openai_api_key"
            )
            
            keyField(
                label: "Google Gemini",
                placeholder: "AIzaSy...",
                value: $viewModel.geminiKey,
                keyName: "gemini_api_key"
            )
            
            keyField(
                label: "Groq Cloud (Llama 3.3)",
                placeholder: "gsk_...",
                value: $viewModel.groqKey,
                keyName: "groq_api_key"
            )
            
            keyField(
                label: "DeepSeek",
                placeholder: "sk-...",
                value: $viewModel.deepSeekKey,
                keyName: "deepseek_api_key"
            )
        }
    }
    
    private func keyField(label: String, placeholder: String, value: Binding<String>, keyName: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color.white.opacity(0.85))
            
            SecureField(placeholder, text: value)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.06))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .onChange(of: value.wrappedValue) { _, newValue in
                    viewModel.saveKeychainKey(name: keyName, value: newValue)
                }
        }
    }
    
    private var companionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("COMPANION MICRO-SERVER")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.5))
            
            HStack {
                Circle()
                    .fill(viewModel.companionServer.isRunning ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(viewModel.companionServer.isRunning ? "Server active on port \(viewModel.companionServer.port)" : "Server stopped")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.9))
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Extension Pairing Token")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.85))
                
                HStack {
                    Text(viewModel.companionServer.pairingToken)
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.7))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(viewModel.companionServer.pairingToken, forType: .string)
                        isTokenCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            isTokenCopied = false
                        }
                    }) {
                        Text(isTokenCopied ? "Copied" : "Copy")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(isTokenCopied ? .green : .cyan)
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(Color.white.opacity(0.06))
                .cornerRadius(8)
            }
            
            Text("Enter this token in the Natively Chrome extension or open http://localhost:\(viewModel.companionServer.port) on your phone to mirror answers in real time.")
                .font(.system(size: 11.5))
                .foregroundColor(Color.white.opacity(0.5))
                .lineSpacing(3)
        }
    }
}
