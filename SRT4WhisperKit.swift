import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var originalContent = ""  // Left-side original text content
    @State private var srtContent = ""       // Right-side converted SRT content
    @State private var replaceTarget = ""
    @State private var replaceWith = ""
    @State private var logMessage = ""
    @State private var originalFileURL: URL? = nil  // Original file path for saving
    @State private var showTipAlert = false  // Show tip alert

    var body: some View {
        HStack {
            // Left-side text editor
            VStack(alignment: .center) {
                TextEditor(text: $originalContent)
                    .padding()
                    .border(Color.gray, width: 1)
                    .frame(minWidth: 300, minHeight: 400)
                
                Button("Clear") {
                    originalContent = ""
                }
                .padding(.top, 10)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            
            // Center control buttons
            VStack(spacing: 20) {
                Button("Open File") {
                    openFile()
                }
                Button("Convert to SRT") {
                    convertOriginalToSRT()
                }
                
                // Batch convert and tip button
                HStack {
                    Button("Batch Convert") {
                        selectFolderOrMultipleFiles()
                    }
                    Button(action: {
                        showTipAlert = true
                    }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .alert(isPresented: $showTipAlert) {
                        Alert(
                            title: Text("Batch Convert Tip"),
                            message: Text("You can select a folder or multiple files for batch conversion"),
                            dismissButton: .default(Text("Got it"))
                        )
                    }
                }
                
                Text("Batch Replace")
                TextField("Text to Replace", text: $replaceTarget)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("Replace With", text: $replaceWith)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Replace") {
                    replaceWords()
                }
                Button("Save as SRT") {
                    saveAsSRTFile()
                }
            }
            .padding(.horizontal, 20)
            
            // Right-side text editor
            VStack(alignment: .center) {
                TextEditor(text: $srtContent)
                    .padding()
                    .border(Color.gray, width: 1)
                    .frame(minWidth: 300, minHeight: 400)
                
                Button("Clear") {
                    srtContent = ""
                }
                .padding(.top, 10)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding()
    }
    
    // Convert left-side original content to SRT format
    func convertOriginalToSRT() {
        srtContent = convertToSRT(originalContent)
    }
    
    // Open a single file and load its content into the left-side text editor
    func openFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.item]  // Allows selection of any file type
        panel.begin { response in
            if response == .OK, let fileURL = panel.url {
                do {
                    let content = try String(contentsOf: fileURL, encoding: .utf8)
                    DispatchQueue.main.async {
                        originalContent = content
                        originalFileURL = fileURL  // Save original file path
                    }
                } catch {
                    logMessage = "Unable to open file: \(error)"
                }
            }
        }
    }
    
    // Open a folder or multiple files and batch convert
    func selectFolderOrMultipleFiles() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.item]  // Allows selection of any file type
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        
        panel.begin { response in
            if response == .OK {
                let selectedURLs = panel.urls
                chooseOutputFolder { outputFolder in
                    DispatchQueue.global(qos: .userInitiated).async {
                        for url in selectedURLs {
                            if url.hasDirectoryPath {
                                processFolder(url, outputFolder: outputFolder)
                            } else {
                                processAndSaveSingleFile(url, outputFolder: outputFolder)
                            }
                        }
                        DispatchQueue.main.async {
                            logMessage += "\nBatch conversion complete! Files saved in selected output folder."
                        }
                    }
                }
            }
        }
    }
    
    // Choose an output folder
    func chooseOutputFolder(completion: @escaping (URL) -> Void) {
        let savePanel = NSOpenPanel()
        savePanel.canChooseFiles = false
        savePanel.canChooseDirectories = true
        savePanel.allowsMultipleSelection = false
        savePanel.prompt = "Select Output Folder"
        
        savePanel.begin { response in
            if response == .OK, let outputFolder = savePanel.url {
                completion(outputFolder)
            } else {
                logMessage += "\nUser canceled output folder selection."
            }
        }
    }
    
    // Process a folder
    func processFolder(_ folderURL: URL, outputFolder: URL) {
        do {
            let txtFiles = try FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "txt" }
            for txtFile in txtFiles {
                processAndSaveSingleFile(txtFile, outputFolder: outputFolder)
            }
        } catch {
            DispatchQueue.main.async {
                logMessage += "\nFailed to read folder: \(error)"
            }
        }
    }
    
    // Process a single file and save to specified output folder
    func processAndSaveSingleFile(_ fileURL: URL, outputFolder: URL) {
        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let srtContent = convertToSRT(content)
            
            let srtFileURL = outputFolder.appendingPathComponent(fileURL.deletingPathExtension().lastPathComponent).appendingPathExtension("srt")
            try srtContent.write(to: srtFileURL, atomically: true, encoding: .utf8)
            
            DispatchQueue.main.async {
                logMessage += "\nConversion successful: \(fileURL.lastPathComponent) -> \(srtFileURL.lastPathComponent)"
            }
        } catch {
            DispatchQueue.main.async {
                logMessage += "\nConversion failed: \(fileURL.lastPathComponent), error: \(error)"
            }
        }
    }
    
    // Convert to SRT format
    func convertToSRT(_ content: String) -> String {
        let lines = content.split(separator: "\n")
        var srtLines: [String] = []
        var index = 1
        
        for line in lines {
            if line.contains("-->") {
                let components = line.split(separator: "]")
                if components.count > 1 {
                    let timeString = components[0].replacingOccurrences(of: "[", with: "")
                    let subtitleText = components[1].trimmingCharacters(in: .whitespaces)
                    
                    let times = timeString.split(separator: " --> ")
                    if times.count == 2 {
                        let start = formatTime(Double(times[0]) ?? 0)
                        let end = formatTime(Double(times[1]) ?? 0)
                        
                        srtLines.append("\(index)")
                        srtLines.append("\(start) --> \(end)")
                        srtLines.append(subtitleText)
                        srtLines.append("")
                        index += 1
                    }
                }
            }
        }
        
        return srtLines.joined(separator: "\n")
    }
    
    func formatTime(_ time: Double) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time - Double(Int(time))) * 1000)
        
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, milliseconds)
    }
    
    // Batch replace words and clear the replace fields
    func replaceWords() {
        srtContent = srtContent.replacingOccurrences(of: replaceTarget, with: replaceWith)
        replaceTarget = ""  // Clear replacement target
        replaceWith = ""    // Clear replacement text
    }
    
    // Save as SRT file and clear input and output fields upon success
    func saveAsSRTFile() {
        guard !srtContent.isEmpty else { return }
        
        let savePanel = NSSavePanel()
        let defaultFileName = originalFileURL?.deletingPathExtension().lastPathComponent ?? "output"
        savePanel.nameFieldStringValue = "\(defaultFileName).srt"
        savePanel.allowedContentTypes = [UTType(filenameExtension: "srt") ?? .plainText]
        
        savePanel.begin { response in
            if response == .OK, let srtFileURL = savePanel.url {
                do {
                    try srtContent.write(to: srtFileURL, atomically: true, encoding: .utf8)
                    srtContent = ""  // Clear output field upon save
                    originalContent = ""  // Clear input field upon save
                } catch {
                    print("Save failed: \(error)")
                }
            }
        }
    }
}
