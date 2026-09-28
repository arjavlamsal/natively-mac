import SwiftUI
import NativelySecurity

/// Comprehensive Settings sheet adhering to macOS Human Interface Guidelines.
/// Configures AI credentials in macOS Keychain, speech recognition engines,
/// hardware stealth isolation, browser companion pairing, and user profile intelligence.
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
            // Header Bar
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape.2.fill")
                        .font(.system(size: 15))
                        .foregroundColor(NativelyTheme.purpleAccent)
                    Text("Settings")
                        .font(.system(size: 15, weight: .bold))
                }
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider()
                .opacity(0.6)
            
            // Tab Picker Bar
            HStack(spacing: 4) {
                tabButton(title: "AI Credentials", systemImage: "key.fill", tag: 0)
                tabButton(title: "Audio & STT", systemImage: "waveform", tag: 1)
                tabButton(title: "Stealth & Hotkeys", systemImage: "shield.lefthalf.filled", tag: 2)
                tabButton(title: "Companion", systemImage: "safari.fill", tag: 3)
                tabButton(title: "Profile", systemImage: "person.crop.circle", tag: 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            
            Divider()
                .opacity(0.5)
            
            // Tab Content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
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
                .padding(20)
            }
        }
        .frame(width: 580, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Tab Button
    
    private func tabButton(title: String, systemImage: String, tag: Int) -> some View {
        let isSelected = selectedTab == tag
        return Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                selectedTab = tag
            }
        }) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                Text(title)
                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular))
            }
            .foregroundColor(isSelected ? .white : .primary.opacity(0.8))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Tab 0: AI Credentials
    
    private var apiKeysSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("API Credentials")
                    .font(.system(size: 13, weight: .bold))
                Text("Keys are encrypted and stored in your local macOS Keychain. They never leave your Mac except when making direct, encrypted calls to the AI provider.")
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 12) {
                keyField(
                    label: "Anthropic Claude (Claude 3.5 Sonnet)",
                    placeholder: "sk-ant-...",
                    value: $viewModel.anthropicKey,
                    keyName: "anthropic_api_key",
                    icon: "brain.head.profile"
                )
                
                keyField(
                    label: "OpenAI (GPT-4o)",
                    placeholder: "sk-proj-...",
                    value: $viewModel.openAIKey,
                    keyName: "openai_api_key",
                    icon: "bolt.fill"
                )
                
                keyField(
                    label: "Google Gemini (Gemini 2.0 Flash / Pro)",
                    placeholder: "AIzaSy...",
                    value: $viewModel.geminiKey,
                    keyName: "gemini_api_key",
                    icon: "sparkles"
                )
                
                keyField(
                    label: "Groq Cloud (Fast Text / Llama 3.3)",
                    placeholder: "gsk_...",
                    value: $viewModel.groqKey,
                    keyName: "groq_api_key",
                    icon: "flame.fill"
                )
                
                keyField(
                    label: "DeepSeek (DeepSeek V3)",
                    placeholder: "sk-...",
                    value: $viewModel.deepSeekKey,
                    keyName: "deepseek_api_key",
                    icon: "globe"
                )
            }
            .padding(14)
            .nativeCard()
        }
    }
    
    private func keyField(label: String, placeholder: String, value: Binding<String>, keyName: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(NativelyTheme.purpleAccent)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !value.wrappedValue.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 10))
                        Text("Saved")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(NativelyTheme.emeraldGreen)
                }
            }
            
            SecureField(placeholder, text: value)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11.5, design: .monospaced))
                .onChange(of: value.wrappedValue) { _, newValue in
                    viewModel.saveKeychainKey(name: keyName, value: newValue)
                }
        }
    }
    
    // MARK: - Tab 1: Audio & STT
    
    private var audioSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Speech Recognition Engine")
                    .font(.system(size: 13, weight: .bold))
                Text("Select the transcription engine used to convert live microphone and system audio into text.")
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                Picker("STT Engine", selection: $sttEngine) {
                    Text("WhisperKit (Apple Silicon On-Device Neural Engine)").tag("whisperkit")
                    Text("Apple Speech (macOS Native SFSpeechRecognizer)").tag("apple_speech")
                    Text("Groq Whisper Cloud (Ultra-Fast Remote Transcription)").tag("groq_cloud")
                }
                .pickerStyle(.radioGroup)
            }
            .padding(14)
            .nativeCard()
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Audio Capture Pipeline")
                    .font(.system(size: 13, weight: .bold))
            }
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "mic.fill")
                        .foregroundColor(NativelyTheme.emeraldGreen)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Microphone Channel (Your Voice)")
                            .font(.system(size: 12, weight: .medium))
                        Text("Recorded via AVAudioEngine with real-time resampling to 16kHz mono")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                    .opacity(0.4)
                
                HStack {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(NativelyTheme.cyanBlue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("System Loopback Channel (Interviewer / Participants)")
                            .font(.system(size: 12, weight: .medium))
                        Text("Captured via ScreenCaptureKit audio tap without requiring virtual drivers")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                    .opacity(0.4)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Voice Activity Detection (VAD) Sensitivity")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Text("\(Int(vadThreshold * 100))%")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $vadThreshold, in: 0.1...0.9, step: 0.05)
                }
            }
            .padding(14)
            .nativeCard()
        }
    }
    
    // MARK: - Tab 2: Stealth & Hotkeys
    
    private var stealthSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Hardware Stealth Isolation")
                    .font(.system(size: 13, weight: .bold))
                Text("Natively configures its floating panels at the CoreGraphics window server level to be invisible during screen sharing.")
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 12) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 26))
                    .foregroundColor(NativelyTheme.emeraldGreen)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Hardware Level Stealth Enforced")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Enforces window sharingType = .none. The overlay panel is completely invisible to ScreenCaptureKit, Zoom, Microsoft Teams, Google Meet, and QuickTime recordings.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineSpacing(2)
                }
            }
            .padding(14)
            .background(NativelyTheme.emeraldGreen.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(NativelyTheme.emeraldGreen.opacity(0.25), lineWidth: 0.5)
            )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Global Keyboard Shortcuts")
                    .font(.system(size: 13, weight: .bold))
            }
            
            VStack(spacing: 8) {
                shortcutRow(action: "Toggle Stealth Overlay Visibility", key: "⌘B")
                shortcutRow(action: "Interactive Screen Crop & Vision OCR", key: "⌘⇧X")
                shortcutRow(action: "Toggle Mouse Click Passthrough", key: "⌘⇧B")
                shortcutRow(action: "Instant What Should I Say? (BLUF)", key: "⌘1")
                shortcutRow(action: "Suggest Clarifying Questions", key: "⌘2")
                shortcutRow(action: "Recap Constraints & Approaches", key: "⌘3")
                shortcutRow(action: "Follow-up Optimization Points", key: "⌘4")
            }
            .padding(14)
            .nativeCard()
        }
    }
    
    private func shortcutRow(action: String, key: String) -> some View {
        HStack {
            Text(action)
                .font(.system(size: 12))
            Spacer()
            Text(key)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        }
    }
    
    // MARK: - Tab 3: Companion Extension
    
    private var companionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Browser Companion Server")
                    .font(.system(size: 13, weight: .bold))
                Text("Connects the Natively Chrome & Safari extension to capture problem descriptions, constraints, and test cases.")
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Circle()
                        .fill(viewModel.companionServer.isRunning ? NativelyTheme.emeraldGreen : NativelyTheme.dangerRed)
                        .frame(width: 8, height: 8)
                    Text(viewModel.companionServer.isRunning ? "Loopback Server Active on Port \(viewModel.companionServer.port)" : "Server Offline")
                        .font(.system(size: 12.5, weight: .medium))
                    
                    Spacer()
                    
                    Text("127.0.0.1")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .opacity(0.4)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Pairing Security Token")
                        .font(.system(size: 12, weight: .medium))
                    
                    HStack {
                        Text(viewModel.companionServer.pairingToken)
                            .font(.system(size: 11.5, design: .monospaced))
                            .foregroundColor(.secondary)
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
                            Label(isTokenCopied ? "Copied" : "Copy Token", systemImage: isTokenCopied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 11.5))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }
            .padding(14)
            .nativeCard()
        }
    }
    
    // MARK: - Tab 4: Profile Intelligence
    
    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Profile Intelligence Context")
                    .font(.system(size: 13, weight: .bold))
                Text("Add your resume summary, tech stack, and experience. Answers will be customized to reflect your true professional identity.")
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
            }
            
            TextEditor(text: $profileContext)
                .font(.system(size: 12, design: .monospaced))
                .frame(minHeight: 220)
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.8), lineWidth: 0.5)
                )
        }
    }
}
