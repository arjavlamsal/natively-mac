import SwiftUI
import NativelySecurity

/// Comprehensive Settings sheet providing configuration for AI credentials,
/// dual-channel audio STT devices, hardware stealth options, companion pairing,
/// and profile intelligence context.
public struct SettingsSheetView: View {
    @ObservedObject public var viewModel: LauncherViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab = 0
    @State private var isTokenCopied = false
    
    // Audio Settings
    @AppStorage("natively_stt_engine") private var sttEngine: String = "whisperkit"
    @AppStorage("natively_vad_threshold") private var vadThreshold: Double = 0.5
    
    // Stealth Settings
    @AppStorage("natively_undetectable") private var isUndetectable: Bool = true
    
    // Profile Intelligence
    @AppStorage("natively_profile_context") private var profileContext: String = ""
    
    public init(viewModel: LauncherViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 15))
                        .foregroundColor(.purple)
                    Text("Preferences")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(16)
            
            Divider().background(Color.white.opacity(0.1))
            
            // Tab Picker
            Picker("", selection: $selectedTab) {
                Text("AI Keys").tag(0)
                Text("Audio & STT").tag(1)
                Text("Stealth & Keys").tag(2)
                Text("Companion").tag(3)
                Text("Profile").tag(4)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            
            // Tab Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedTab {
                    case 0:
                        apiKeysSection
                    case 1:
                        audioSection
                    case 2:
                        stealthSection
                    case 3:
                        companionSection
                    case 4:
                        profileSection
                    default:
                        EmptyView()
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 560, height: 500)
        .background(Color(red: 0.10, green: 0.11, blue: 0.15))
    }
    
    // MARK: - Tab 0: AI Keys
    private var apiKeysSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("API CREDENTIALS (SECURELY ENCRYPTED IN KEYCHAIN)")
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.5))
            
            keyField(
                label: "Anthropic Claude (Claude 3.5 Sonnet)",
                placeholder: "sk-ant-...",
                value: $viewModel.anthropicKey,
                keyName: "anthropic_api_key"
            )
            
            keyField(
                label: "OpenAI (GPT-4o)",
                placeholder: "sk-proj-...",
                value: $viewModel.openAIKey,
                keyName: "openai_api_key"
            )
            
            keyField(
                label: "Google Gemini (Gemini 2.0 Flash / Pro)",
                placeholder: "AIzaSy...",
                value: $viewModel.geminiKey,
                keyName: "gemini_api_key"
            )
            
            keyField(
                label: "Groq Cloud (Fast Text / Llama 3.3)",
                placeholder: "gsk_...",
                value: $viewModel.groqKey,
                keyName: "groq_api_key"
            )
            
            keyField(
                label: "DeepSeek (DeepSeek V3)",
                placeholder: "sk-...",
                value: $viewModel.deepSeekKey,
                keyName: "deepseek_api_key"
            )
        }
    }
    
    private func keyField(label: String, placeholder: String, value: Binding<String>, keyName: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(Color.white.opacity(0.85))
            
            SecureField(placeholder, text: value)
                .textFieldStyle(.plain)
                .font(.system(size: 11.5, design: .monospaced))
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
    
    // MARK: - Tab 1: Audio & STT
    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SPEECH-TO-TEXT ENGINE")
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.5))
            
            Picker("STT Engine", selection: $sttEngine) {
                Text("WhisperKit (Apple Silicon On-Device Neural Engine)").tag("whisperkit")
                Text("Apple Speech (macOS Native SFSpeechRecognizer)").tag("apple_speech")
                Text("Groq Whisper Cloud (Ultra-Fast)").tag("groq_cloud")
            }
            .pickerStyle(.radioGroup)
            .foregroundColor(.white)
            
            Divider().background(Color.white.opacity(0.1))
            
            Text("AUDIO CAPTURE CHANNELS")
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.5))
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.green)
                    Text("Microphone Channel (Your Voice)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                    Spacer()
                    Text("Default Input")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.5))
                }
                
                HStack {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(.cyan)
                    Text("System Loopback Channel (Interviewer)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                    Spacer()
                    Text("CoreAudio Loopback")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.5))
                }
            }
            .padding(10)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Voice Activity Detection Sensitivity: \(Int(vadThreshold * 100))%")
                    .font(.system(size: 11.5))
                    .foregroundColor(Color.white.opacity(0.8))
                Slider(value: $vadThreshold, in: 0.1...0.9, step: 0.05)
            }
        }
    }
    
    // MARK: - Tab 2: Stealth & Keys
    private var stealthSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("HARDWARE STEALTH & CAPTURE ISOLATION")
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.5))
            
            HStack(spacing: 10) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 22))
                    .foregroundColor(Color.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hardware Level Stealth Active")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Enforces window sharingType = .none. The overlay panel is completely invisible to ScreenCaptureKit, Zoom, Microsoft Teams, Google Meet, and QuickTime.")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.6))
                        .lineSpacing(2)
                }
            }
            .padding(12)
            .background(Color.green.opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.green.opacity(0.2), lineWidth: 1)
            )
            
            Divider().background(Color.white.opacity(0.1))
            
            Text("GLOBAL KEYBOARD SHORTCUTS")
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.5))
            
            VStack(spacing: 6) {
                keybindRow(action: "Toggle Stealth Overlay Visibility", key: "⌘B")
                keybindRow(action: "Crop Screen Region & Optical OCR", key: "⌘⇧X")
                keybindRow(action: "Toggle Mouse Click Passthrough", key: "⌘⇧B")
                keybindRow(action: "Instant What Should I Say? (BLUF)", key: "⌘1")
                keybindRow(action: "Suggest Clarifying Questions", key: "⌘2")
                keybindRow(action: "Recap Constraints & Approaches", key: "⌘3")
                keybindRow(action: "Follow-up Optimization Points", key: "⌘4")
            }
        }
    }
    
    private func keybindRow(action: String, key: String) -> some View {
        HStack {
            Text(action)
                .font(.system(size: 11.5))
                .foregroundColor(Color.white.opacity(0.8))
            Spacer()
            Text(key)
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.1))
                .cornerRadius(4)
        }
        .padding(.vertical, 2)
    }
    
    // MARK: - Tab 3: Companion & Phone
    private var companionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("COMPANION MICRO-SERVER & BROWSER EXTENSION")
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.5))
            
            HStack {
                Circle()
                    .fill(viewModel.companionServer.isRunning ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                Text(viewModel.companionServer.isRunning ? "Active on loopback port \(viewModel.companionServer.port)" : "Server stopped")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.9))
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.05))
            .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Extension Pairing Token")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.85))
                
                HStack {
                    Text(viewModel.companionServer.pairingToken)
                        .font(.system(size: 11, design: .monospaced))
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
            
            Text("Enter this token in the Natively Chrome extension to sync LeetCode, HackerRank, or web questions directly to your AI context.")
                .font(.system(size: 11))
                .foregroundColor(Color.white.opacity(0.5))
                .lineSpacing(2)
        }
    }
    
    // MARK: - Tab 4: Profile Intelligence
    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PROFILE INTELLIGENCE CONTEXT")
                .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.5))
            
            Text("Paste your resume, technical background, work experience, or bio below. Natively automatically injects this context into answers so responses match your real background during behavioral and technical questions.")
                .font(.system(size: 11.5))
                .foregroundColor(Color.white.opacity(0.65))
                .lineSpacing(2)
            
            TextEditor(text: $profileContext)
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundColor(.white)
                .frame(minHeight: 180)
                .padding(8)
                .background(Color.white.opacity(0.04))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        }
    }
}
