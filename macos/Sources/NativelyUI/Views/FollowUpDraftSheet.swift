import SwiftUI
import AppKit
import NativelyCore
import NativelyAI

/// Modal sheet for generating, reviewing, and exporting meeting follow-up communications.
public struct FollowUpDraftSheet: View {
    public let meeting: Meeting
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTone: FollowUpTone = .concise
    @State private var selectedType: FollowUpDraftType = .email
    @State private var draftSubject: String = ""
    @State private var draftBody: String = ""
    @State private var isCopied: Bool = false
    
    public init(meeting: Meeting) {
        self.meeting = meeting
        let defaultType = FollowUpDraftGenerator.defaultDraftType(for: nil)
        _selectedType = State(initialValue: defaultType)
        let initialDraft = FollowUpDraftGenerator.generateDraft(
            meeting: meeting,
            modeId: nil,
            tone: .concise,
            draftType: defaultType
        )
        _draftSubject = State(initialValue: initialDraft.subject)
        _draftBody = State(initialValue: initialDraft.body)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Draft Follow-Up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(NativelyTheme.textPrimary)
                    Text(meeting.title ?? "Meeting Follow-Up")
                        .font(.system(size: 12))
                        .foregroundColor(NativelyTheme.textSecondary)
                }
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(NativelyTheme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            
            // Format & Tone Selectors
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DRAFT TYPE")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundColor(NativelyTheme.textTertiary)
                    
                    Picker("", selection: $selectedType) {
                        ForEach(FollowUpDraftType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("TONE")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundColor(NativelyTheme.textTertiary)
                    
                    Picker("", selection: $selectedTone) {
                        ForEach(FollowUpTone.allCases, id: \.self) { tone in
                            Text(tone.displayName).tag(tone)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
                
                Spacer()
                
                Button("Regenerate") {
                    regenerateDraft()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .onChange(of: selectedTone) { _, _ in regenerateDraft() }
            .onChange(of: selectedType) { _, _ in regenerateDraft() }
            
            Divider().background(NativelyTheme.borderSubtle)
            
            // Subject Field
            VStack(alignment: .leading, spacing: 4) {
                Text("SUBJECT")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundColor(NativelyTheme.textTertiary)
                
                TextField("Subject", text: $draftSubject)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12.5, weight: .medium))
            }
            
            // Body Editor
            VStack(alignment: .leading, spacing: 4) {
                Text("MESSAGE CONTENT")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundColor(NativelyTheme.textTertiary)
                
                TextEditor(text: $draftBody)
                    .font(.system(size: 12))
                    .foregroundColor(NativelyTheme.textPrimary)
                    .padding(8)
                    .background(NativelyTheme.bgCard)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(NativelyTheme.borderMuted, lineWidth: 0.5)
                    )
            }
            
            // Footer Action Buttons
            HStack(spacing: 10) {
                Button(action: openInMail) {
                    HStack(spacing: 5) {
                        Image(systemName: "envelope.fill")
                        Text("Open in Mail.app")
                    }
                    .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button(action: copyToClipboard) {
                    HStack(spacing: 5) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        Text(isCopied ? "Copied" : "Copy to Clipboard")
                    }
                    .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 580, height: 520)
        .background(NativelyTheme.bgPrimary)
    }
    
    private func regenerateDraft() {
        let draft = FollowUpDraftGenerator.generateDraft(
            meeting: meeting,
            modeId: nil,
            tone: selectedTone,
            draftType: selectedType
        )
        draftSubject = draft.subject
        draftBody = draft.body
    }
    
    private func copyToClipboard() {
        let full = "Subject: \(draftSubject)\n\n\(draftBody)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(full, forType: .string)
        isCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isCopied = false
        }
    }
    
    private func openInMail() {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = ""
        components.queryItems = [
            URLQueryItem(name: "subject", value: draftSubject),
            URLQueryItem(name: "body", value: draftBody)
        ]
        if let mailtoURL = components.url {
            NSWorkspace.shared.open(mailtoURL)
        }
    }
}
