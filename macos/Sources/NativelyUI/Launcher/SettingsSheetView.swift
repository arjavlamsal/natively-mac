import SwiftUI
import NativelySecurity
import NativelyAudio
import NativelyCore
import UniformTypeIdentifiers

/// Settings modal replicating the original Natively SettingsOverlay layout.
/// Features a dark sidebar with icon navigation, header with close action,
/// and dark elevated cards for AI credentials, audio configuration, stealth, and profile context.
public struct SettingsSheetView: View {
    @ObservedObject public var viewModel: LauncherViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab = "ai-providers"
    @State private var isTokenCopied = false
    
    // Audio Settings
    @AppStorage("natively_stt_engine") private var sttEngine: String = "apple-speech"
    @AppStorage("natively_vad_threshold") private var vadThreshold: Double = 0.5
    @AppStorage("natively_selected_mic") private var selectedMicId: String = "default"
    
    // Stealth Settings
    @AppStorage("natively_undetectable") private var isUndetectable: Bool = true
    
    // Profile Intelligence
    @AppStorage("natively_profile_context") private var profileContext: String = ""
    @State private var documentIngestStatus: String? = nil
    
    // Custom Modes
    @State private var showCreateMode: Bool = false
    @State private var newModeName: String = ""
    @State private var newModePrompt: String = ""
    @State private var newModeDesc: String = ""
    
    public init(viewModel: LauncherViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            // LEFT SIDEBAR (Width: 210)
            sidebarView
                .frame(width: 210)
                .background(NativelyTheme.bgSecondary)
            
            Divider()
                .background(NativelyTheme.borderSubtle)
            
            // RIGHT CONTENT PANEL
            VStack(alignment: .leading, spacing: 0) {
                // Header (Title, Subtitle & Close Button)
                panelHeaderBar
                
                Divider()
                    .background(NativelyTheme.borderSubtle)
                
                // Panel Scrollable Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        switch selectedTab {
                        case "general":
                            generalSection
                        case "ai-providers":
                            aiProvidersSection
                        case "modes":
                            modesSection
                        case "audio":
                            audioDevicesSection
                        case "stealth":
                            stealthSection
                        case "keybinds":
                            keybindsSection
                        case "companion":
                            companionSection
                        case "profile":
                            profileSection
                        case "about":
                            aboutSection
                        default:
                            aiProvidersSection
                        }
                    }
                    .padding(24)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(NativelyTheme.bgPrimary)
        }
        .frame(width: 820, height: 580)
        .enforceStealthMode()
        .onAppear {
            selectedTab = viewModel.settingsSelectedTab
            viewModel.loadModes()
        }
    }
    
    // MARK: - Left Sidebar
    
    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App Title & Version Header
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(NativelyTheme.purpleAccent.opacity(0.2))
                        .frame(width: 26, height: 26)
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(NativelyTheme.purpleAccent)
                }
                
                Text("Settings")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(NativelyTheme.textPrimary)
                
                Spacer()
                
                Text("v2.7")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundColor(NativelyTheme.emeraldGreen)
                    .padding(.horizontal, 4.5)
                    .padding(.vertical, 1.5)
                    .background(NativelyTheme.emeraldGreen.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 14)
            
            Divider()
                .background(NativelyTheme.borderSubtle)
            
            // Nav Items List
            ScrollView {
                VStack(spacing: 2) {
                    sidebarNavItem(id: "general", label: "General", icon: "gearshape")
                    sidebarNavItem(id: "ai-providers", label: "AI Providers", icon: "brain.head.profile")
                    sidebarNavItem(id: "modes", label: "Modes & Prompts", icon: "square.grid.2x2")
                    sidebarNavItem(id: "audio", label: "Audio & Devices", icon: "waveform")
                    sidebarNavItem(id: "stealth", label: "Stealth Mode", icon: "shield.lefthalf.filled")
                    sidebarNavItem(id: "keybinds", label: "Keybinds", icon: "keyboard")
                    sidebarNavItem(id: "companion", label: "Companion", icon: "network")
                    sidebarNavItem(id: "profile", label: "Intelligence", icon: "person.crop.circle")
                    sidebarNavItem(id: "about", label: "About", icon: "info.circle")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 10)
            }
        }
    }
    
    private func sidebarNavItem(id: String, label: String, icon: String) -> some View {
        let isSelected = selectedTab == id
        return Button(action: {
            withAnimation(NativelyTheme.quickSpring) {
                selectedTab = id
            }
        }) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 12.5))
                    .foregroundColor(isSelected ? NativelyTheme.skyAccent : NativelyTheme.textSecondary)
                    .frame(width: 18)
                
                Text(label)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? NativelyTheme.textPrimary : NativelyTheme.textSecondary)
                
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                isSelected ? Color.white.opacity(0.08) : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.white.opacity(0.12) : Color.clear, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Right Panel Header
    
    private var panelHeaderBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(panelTitle)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(NativelyTheme.textPrimary)
                Text(panelSubtitle)
                    .font(.system(size: 11.5))
                    .foregroundColor(NativelyTheme.textTertiary)
            }
            
            Spacer()
            
            // Close Button (✕)
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(NativelyTheme.textSecondary)
                    .padding(6)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .help("Close Settings")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(NativelyTheme.bgSecondary)
    }
    
    private var panelTitle: String {
        switch selectedTab {
        case "general": return "General Preferences"
        case "ai-providers": return "AI Providers & Credentials"
        case "modes": return "Modes & System Prompts"
        case "audio": return "Audio Capture & STT"
        case "stealth": return "Hardware Stealth & Isolation"
        case "keybinds": return "Global Keyboard Shortcuts"
        case "companion": return "Browser Companion Server"
        case "profile": return "Profile Intelligence Context"
        case "about": return "About Natively"
        default: return "Settings"
        }
    }
    
    private var panelSubtitle: String {
        switch selectedTab {
        case "general": return "Application behavior, startup, and interface appearance"
        case "ai-providers": return "Configure custom API keys stored securely in macOS Keychain"
        case "modes": return "Configure built-in personas or create tailored custom prompts"
        case "audio": return "Select speech recognition engines, audio channels, and VAD thresholds"
        case "stealth": return "Hardware-level window isolation parameters"
        case "keybinds": return "Quick trigger hotkeys for overlays, cropping, and instant presets"
        case "companion": return "Pair local browser extension to sync problems and questions"
        case "profile": return "Add professional background and resume to ground AI answers"
        case "about": return "Version, architecture, and system information"
        default: return ""
        }
    }
    
    // MARK: - AI Providers Section
    
    private var aiProvidersSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            keyField(
                label: "Anthropic Claude (Claude 3.7 Sonnet / 3.5 Sonnet)",
                placeholder: "sk-ant-...",
                value: $viewModel.anthropicKey,
                keyName: "anthropic_api_key",
                icon: "brain.head.profile"
            )
            
            keyField(
                label: "Google Gemini (Gemini 3.8 Flash / 3.5 Flash Lite / 3.1 Pro)",
                placeholder: "AIzaSy...",
                value: $viewModel.geminiKey,
                keyName: "gemini_api_key",
                icon: "sparkles"
            )
            
            keyField(
                label: "OpenAI (GPT-4o / o3-mini)",
                placeholder: "sk-proj-...",
                value: $viewModel.openAIKey,
                keyName: "openai_api_key",
                icon: "bolt.fill"
            )
            
            keyField(
                label: "Groq Cloud (Fast Llama 3.3 70B)",
                placeholder: "gsk_...",
                value: $viewModel.groqKey,
                keyName: "groq_api_key",
                icon: "flame.fill"
            )
            
            keyField(
                label: "DeepSeek (DeepSeek V3 / R1)",
                placeholder: "sk-...",
                value: $viewModel.deepSeekKey,
                keyName: "deepseek_api_key",
                icon: "globe"
            )
        }
    }
    
    private func keyField(label: String, placeholder: String, value: Binding<String>, keyName: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(NativelyTheme.purpleAccent)
                Text(label)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(NativelyTheme.textPrimary)
                
                Spacer()
                
                if !value.wrappedValue.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 10))
                        Text("Saved in Keychain")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(NativelyTheme.emeraldGreen)
                }
            }
            
            SecureField(placeholder, text: value)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(NativelyTheme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(NativelyTheme.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(NativelyTheme.borderMuted, lineWidth: 0.5)
                )
                .onChange(of: value.wrappedValue) { _, newValue in
                    viewModel.saveKeychainKey(name: keyName, value: newValue)
                }
        }
        .padding(14)
        .background(NativelyTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(NativelyTheme.borderSubtle, lineWidth: 0.5)
        )
    }
    
    // MARK: - Modes Section
    
    private var modesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Top Bar: Active Mode & Create Button
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ACTIVE COPILOT MODE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(NativelyTheme.textTertiary)
                    
                    if let active = viewModel.modes.first(where: { $0.isActive }) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(NativelyTheme.emeraldGreen)
                                .frame(width: 8, height: 8)
                            Text(active.name)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(NativelyTheme.textPrimary)
                        }
                    }
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        showCreateMode.toggle()
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: showCreateMode ? "xmark" : "plus")
                        Text(showCreateMode ? "Cancel" : "New Custom Mode")
                    }
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(NativelyTheme.skyAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(NativelyTheme.skyAccent.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .background(NativelyTheme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(NativelyTheme.borderSubtle, lineWidth: 0.5)
            )
            
            // Create New Mode Card (Collapsible)
            if showCreateMode {
                VStack(alignment: .leading, spacing: 10) {
                    Text("CREATE NEW CUSTOM MODE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(NativelyTheme.skyAccent)
                    
                    TextField("Mode Name (e.g. System Design Expert)", text: $newModeName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12.5))
                    
                    TextField("Description (e.g. Tailored for senior architecture interviews)", text: $newModeDesc)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                    
                    Text("SYSTEM PROMPT")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundColor(NativelyTheme.textTertiary)
                    
                    TextEditor(text: $newModePrompt)
                        .font(.system(size: 11.5, design: .monospaced))
                        .frame(height: 100)
                        .padding(6)
                        .background(NativelyTheme.bgElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(NativelyTheme.borderMuted, lineWidth: 0.5)
                        )
                    
                    HStack {
                        Spacer()
                        Button("Save Mode") {
                            viewModel.saveCustomMode(name: newModeName, prompt: newModePrompt, description: newModeDesc.isEmpty ? nil : newModeDesc)
                            newModeName = ""
                            newModePrompt = ""
                            newModeDesc = ""
                            showCreateMode = false
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(newModeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newModePrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(14)
                .background(NativelyTheme.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(NativelyTheme.skyAccent.opacity(0.3), lineWidth: 0.5)
                )
            }
            
            // Modes List
            VStack(spacing: 8) {
                ForEach(viewModel.modes) { mode in
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(mode.name)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(NativelyTheme.textPrimary)
                                
                                if mode.isActive {
                                    Text("ACTIVE")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundColor(NativelyTheme.emeraldGreen)
                                        .padding(.horizontal, 4.5)
                                        .padding(.vertical, 1.5)
                                        .background(NativelyTheme.emeraldGreen.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                                
                                if mode.isCustom {
                                    Text("CUSTOM")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundColor(NativelyTheme.purpleAccent)
                                        .padding(.horizontal, 4.5)
                                        .padding(.vertical, 1.5)
                                        .background(NativelyTheme.purpleAccent.opacity(0.12))
                                        .clipShape(Capsule())
                                } else {
                                    Text("BUILT-IN")
                                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                                        .foregroundColor(NativelyTheme.textTertiary)
                                        .padding(.horizontal, 4.5)
                                        .padding(.vertical, 1.5)
                                        .background(Color.white.opacity(0.06))
                                        .clipShape(Capsule())
                                }
                            }
                            
                            if let desc = mode.description {
                                Text(desc)
                                    .font(.system(size: 11))
                                    .foregroundColor(NativelyTheme.textSecondary)
                                    .lineLimit(1)
                            }
                        }
                        
                        Spacer()
                        
                        if !mode.isActive {
                            Button("Set Active") {
                                viewModel.setActiveMode(mode)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        
                        if mode.isCustom {
                            Button(role: .destructive, action: {
                                viewModel.deleteMode(mode)
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                    .foregroundColor(.red.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 4)
                        }
                    }
                    .padding(12)
                    .background(NativelyTheme.bgCard)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(mode.isActive ? NativelyTheme.emeraldGreen.opacity(0.4) : NativelyTheme.borderSubtle, lineWidth: 0.5)
                    )
                }
            }
        }
    }
    
    // MARK: - Audio & Devices Section
    
    private var audioDevicesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // STT Picker Card
            VStack(alignment: .leading, spacing: 10) {
                Text("SPEECH RECOGNITION ENGINE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(NativelyTheme.textTertiary)
                
                Picker("", selection: $sttEngine) {
                    Text("Apple Speech (macOS Native SFSpeechRecognizer - Fast & Zero-Download)").tag("apple-speech")
                    Text("WhisperKit (Apple Silicon On-Device Neural Engine / GPU)").tag("whisperkit")
                    Text("Groq Whisper Cloud (Ultra-Fast Remote Transcription)").tag("groq_cloud")
                }
                .pickerStyle(.radioGroup)
                .foregroundColor(NativelyTheme.textPrimary)
            }
            .padding(14)
            .background(NativelyTheme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(NativelyTheme.borderSubtle, lineWidth: 0.5)
            )
            
            // Microphone Hardware Device Picker
            VStack(alignment: .leading, spacing: 10) {
                Text("MICROPHONE HARDWARE INPUT")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(NativelyTheme.textTertiary)
                
                Picker("", selection: $selectedMicId) {
                    ForEach(AudioDeviceManager.shared.getAvailableMicrophones()) { device in
                        HStack {
                            Text(device.name)
                            if device.isBuiltIn {
                                Text("(Built-in)").foregroundColor(.secondary)
                            }
                        }
                        .tag(device.id)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            .padding(14)
            .background(NativelyTheme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(NativelyTheme.borderSubtle, lineWidth: 0.5)
            )
            
            // Audio Channels Card
            VStack(alignment: .leading, spacing: 12) {
                Text("AUDIO CAPTURE CHANNELS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(NativelyTheme.textTertiary)
                
                HStack {
                    Image(systemName: "mic.fill")
                        .foregroundColor(NativelyTheme.emeraldGreen)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Microphone Channel (Your Voice)")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundColor(NativelyTheme.textPrimary)
                        Text("AVAudioEngine 16kHz Mono Resampler")
                            .font(.system(size: 11))
                            .foregroundColor(NativelyTheme.textTertiary)
                    }
                    Spacer()
                    Text("Active")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(NativelyTheme.emeraldGreen)
                }
                
                Divider().background(NativelyTheme.borderSubtle)
                
                HStack {
                    Image(systemName: "speaker.wave.2.fill")
                        .foregroundColor(NativelyTheme.cyanBlue)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("System Audio Loopback (Interviewer / Participants)")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundColor(NativelyTheme.textPrimary)
                        Text("ScreenCaptureKit Audio Tap (Hardware Direct)")
                            .font(.system(size: 11))
                            .foregroundColor(NativelyTheme.textTertiary)
                    }
                    Spacer()
                    Text("Active")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(NativelyTheme.cyanBlue)
                }
                
                Divider().background(NativelyTheme.borderSubtle)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Voice Activity Detection (VAD) Sensitivity")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(NativelyTheme.textPrimary)
                        Spacer()
                        Text("\(Int(vadThreshold * 100))%")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(NativelyTheme.skyAccent)
                    }
                    Slider(value: $vadThreshold, in: 0.1...0.9, step: 0.05)
                }
            }
            .padding(14)
            .background(NativelyTheme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(NativelyTheme.borderSubtle, lineWidth: 0.5)
            )
        }
    }
    
    // MARK: - Stealth Section
    
    private var stealthSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 26))
                    .foregroundColor(NativelyTheme.emeraldGreen)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("Hardware Level Stealth Enforced")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(NativelyTheme.textPrimary)
                    Text("Configures window sharingType = .none. The overlay panel is completely invisible to ScreenCaptureKit, Zoom, Microsoft Teams, Google Meet, and QuickTime.")
                        .font(.system(size: 11.5))
                        .foregroundColor(NativelyTheme.textSecondary)
                        .lineSpacing(2)
                }
            }
            .padding(16)
            .background(NativelyTheme.emeraldGreen.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(NativelyTheme.emeraldGreen.opacity(0.25), lineWidth: 0.5)
            )
            
            Toggle(isOn: $isUndetectable) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Enable Hardware Stealth")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(NativelyTheme.textPrimary)
                    Text("When disabled, the overlay is visible in screen shares for demonstration purposes.")
                        .font(.system(size: 11))
                        .foregroundColor(NativelyTheme.textTertiary)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: NativelyTheme.emeraldGreen))
            .onChange(of: isUndetectable) { _, newValue in
                OverlayWindowManager.shared.setStealthMode(newValue)
            }
            .padding(14)
            .background(NativelyTheme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
    
    // MARK: - Keybinds Section
    
    private var keybindsSection: some View {
        VStack(spacing: 6) {
            keybindRow(action: "Toggle Stealth Overlay Visibility", key: "⌘B")
            keybindRow(action: "Interactive Screen Crop & Vision OCR", key: "⌘⇧X")
            keybindRow(action: "Toggle Mouse Click Passthrough", key: "⌘⇧B")
            keybindRow(action: "Instant What Should I Say? (BLUF)", key: "⌘1")
            keybindRow(action: "Suggest Clarifying Questions", key: "⌘2")
            keybindRow(action: "Recap Constraints & Approaches", key: "⌘3")
            keybindRow(action: "Follow-up Optimization Points", key: "⌘4")
        }
        .padding(14)
        .background(NativelyTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(NativelyTheme.borderSubtle, lineWidth: 0.5)
        )
    }
    
    private func keybindRow(action: String, key: String) -> some View {
        HStack {
            Text(action)
                .font(.system(size: 12.5))
                .foregroundColor(NativelyTheme.textSecondary)
            Spacer()
            Text(key)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(NativelyTheme.textPrimary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .padding(.vertical, 3)
    }
    
    // MARK: - Companion Section
    
    private var companionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Circle()
                    .fill(viewModel.companionServer.isRunning ? NativelyTheme.emeraldGreen : NativelyTheme.dangerRed)
                    .frame(width: 8, height: 8)
                Text(viewModel.companionServer.isRunning ? "Loopback Server Active on Port \(viewModel.companionServer.port)" : "Server Stopped")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(NativelyTheme.textPrimary)
                Spacer()
                Text("127.0.0.1")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(NativelyTheme.textTertiary)
            }
            .padding(14)
            .background(NativelyTheme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Extension Pairing Token")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(NativelyTheme.textPrimary)
                
                HStack {
                    Text(viewModel.companionServer.pairingToken)
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundColor(NativelyTheme.textSecondary)
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
                        Text(isTokenCopied ? "Copied" : "Copy Token")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(isTokenCopied ? NativelyTheme.emeraldGreen : NativelyTheme.skyAccent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(NativelyTheme.bgElevated)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(14)
            .background(NativelyTheme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            // Phone Mirror QR Code
            VStack(alignment: .leading, spacing: 10) {
                Text("MOBILE PHONE MIRROR")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(NativelyTheme.textTertiary)
                
                HStack(alignment: .center, spacing: 16) {
                    QRCodeView(content: "http://127.0.0.1:\(viewModel.companionServer.port)/phone?token=\(viewModel.companionServer.pairingToken)")
                        .frame(width: 96, height: 96)
                        .padding(6)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Scan to Mirror Live on Mobile")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(NativelyTheme.textPrimary)
                        Text("Point your iPhone or Android camera at this QR code to view live AI solutions, interview notes, and suggestions directly on your phone.")
                            .font(.system(size: 11))
                            .foregroundColor(NativelyTheme.textSecondary)
                            .lineSpacing(2)
                    }
                }
            }
            .padding(14)
            .background(NativelyTheme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
    
    // MARK: - Profile Section
    
    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Paste your resume, technical background, work experience, or bio below. Natively automatically injects this context so AI responses accurately reflect your true background.")
                .font(.system(size: 12))
                .foregroundColor(NativelyTheme.textSecondary)
                .lineSpacing(2)
            
            // Document Ingestion Action
            HStack(spacing: 10) {
                Button(action: importReferenceDocument) {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 12))
                        Text("Import Document (.pdf, .txt, .md)")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                if let status = documentIngestStatus {
                    Text(status)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(NativelyTheme.emeraldGreen)
                }
            }
            .padding(.vertical, 2)
            
            TextEditor(text: $profileContext)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(NativelyTheme.textPrimary)
                .frame(minHeight: 220)
                .padding(10)
                .background(NativelyTheme.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(NativelyTheme.borderMuted, lineWidth: 0.5)
                )
        }
    }
    
    private func importReferenceDocument() {
        let openPanel = NSOpenPanel()
        var types: [UTType] = [.pdf, .plainText, .utf8PlainText]
        if let mdType = UTType(filenameExtension: "md") {
            types.append(mdType)
        }
        if let markdownType = UTType(filenameExtension: "markdown") {
            types.append(markdownType)
        }
        openPanel.allowedContentTypes = types
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                Task {
                    do {
                        let count = try await viewModel.importReferenceDocument(from: url)
                        await MainActor.run {
                            documentIngestStatus = "Imported \(count) chunk(s) from \(url.lastPathComponent)"
                            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                                documentIngestStatus = nil
                            }
                        }
                    } catch {
                        await MainActor.run {
                            documentIngestStatus = "Error: \(error.localizedDescription)"
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - General & About Section
    
    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 1. System Permissions Card
            VStack(alignment: .leading, spacing: 12) {
                Text("SYSTEM PERMISSIONS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(NativelyTheme.textTertiary)
                
                // Screen Recording
                HStack {
                    Image(systemName: "rectangle.dashed.badge.record")
                        .font(.system(size: 14))
                        .foregroundColor(PermissionsManager.shared.hasScreenRecordingPermission ? NativelyTheme.emeraldGreen : NativelyTheme.warningAmber)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Screen & System Audio Recording")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundColor(NativelyTheme.textPrimary)
                        Text(PermissionsManager.shared.hasScreenRecordingPermission ? "Access granted. Vision OCR and system audio loopback active." : "Required for full-screen analysis, interactive cropping, and system audio.")
                            .font(.system(size: 11))
                            .foregroundColor(NativelyTheme.textTertiary)
                    }
                    
                    Spacer()
                    
                    Button(PermissionsManager.shared.hasScreenRecordingPermission ? "Settings" : "Grant Access") {
                        PermissionsManager.shared.requestScreenRecordingPermission()
                        PermissionsManager.shared.openScreenRecordingSettings()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                Divider().background(NativelyTheme.borderSubtle)
                
                // Microphone
                HStack {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 14))
                        .foregroundColor(PermissionsManager.shared.hasMicrophonePermission ? NativelyTheme.emeraldGreen : NativelyTheme.warningAmber)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Microphone Input")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundColor(NativelyTheme.textPrimary)
                        Text(PermissionsManager.shared.hasMicrophonePermission ? "Access granted. Microphone transcription active." : "Required for voice transcription during interviews and meetings.")
                            .font(.system(size: 11))
                            .foregroundColor(NativelyTheme.textTertiary)
                    }
                    
                    Spacer()
                    
                    Button(PermissionsManager.shared.hasMicrophonePermission ? "Settings" : "Grant Access") {
                        Task {
                            _ = await PermissionsManager.shared.requestMicrophonePermission()
                            PermissionsManager.shared.openMicrophoneSettings()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(14)
            .background(NativelyTheme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(NativelyTheme.borderSubtle, lineWidth: 0.5)
            )
            
            // 2. Preferences
            Toggle(isOn: .constant(true)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto-Start Recording on Meeting Join")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(NativelyTheme.textPrimary)
                    Text("Automatically detect meeting audio and start real-time transcription.")
                        .font(.system(size: 11))
                        .foregroundColor(NativelyTheme.textTertiary)
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: NativelyTheme.skyAccent))
            .padding(14)
            .background(NativelyTheme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .onAppear {
            PermissionsManager.shared.checkAllPermissions()
        }
    }
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 28))
                    .foregroundColor(NativelyTheme.purpleAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Natively macOS Native")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(NativelyTheme.textPrimary)
                    Text("Version 2.7.0 (Apple Silicon Native)")
                        .font(.system(size: 12))
                        .foregroundColor(NativelyTheme.textTertiary)
                }
            }
            .padding(16)
            .background(NativelyTheme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}
