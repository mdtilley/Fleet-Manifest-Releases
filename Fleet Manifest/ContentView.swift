import SwiftUI
import UniformTypeIdentifiers
#if os(iOS) && !targetEnvironment(macCatalyst)
import VisionKit
#endif

// --- 1. GLOBAL PLATFORM HARDWARE CONFIGURATION ---
struct AppConfig {
    static let isScannerAvailable: Bool = {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        return DataScannerViewController.isSupported && DataScannerViewController.isAvailable
        #else
        return false
        #endif
    }()
}

@main
struct FleetManifestApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
            #if os(macOS) || targetEnvironment(macCatalyst)
                .frame(minWidth: 900, minHeight: 600)
            #endif
        }
    }
}

// --- COLOR PALETTE HELPERS ---
let themeColors: [String: Color] = [
    "Cyan": .cyan, "Crimson": .red, "Emerald": .green, "Amethyst": .purple, "Amber": .orange, "Graphite": .gray, "Sapphire": .blue, "Ruby": .pink, "Gold": .yellow
]

let appBackgroundColors: [String: Color] = [
    "OLED Black": .black, "Stealth Black": Color(white: 0.05), "Charcoal": Color(white: 0.12), "Midnight Blue": Color(red: 0.05, green: 0.1, blue: 0.18),
    "Navy": Color(red: 0.0, green: 0.02, blue: 0.15), "Deep Forest": Color(red: 0.05, green: 0.15, blue: 0.1), "Burgundy": Color(red: 0.15, green: 0.0, blue: 0.05), "Dark Plum": Color(red: 0.15, green: 0.05, blue: 0.15)
]

// --- BACKUP DOCUMENT STRUCTURE ---
struct FleetBackup: Codable {
    let devices: [Device]
    let globalParts: [Part]
    let categories: [String]
}

struct ManifestDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var backup: FleetBackup
    
    init(backup: FleetBackup) {
        self.backup = backup
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.backup = try JSONDecoder().decode(FleetBackup.self, from: data)
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder().encode(backup)
        return .init(regularFileWithContents: data)
    }
}

// --- 2. PRIMARY DYNAMIC INTERFACE ---
struct ContentView: View {
    @State private var devices: [Device] = []
    @State private var globalParts: [Part] = []
    @State private var categories: [String] = []
    @State private var searchText: String = ""
    
    @State private var showAddDeviceSheet = false
    @State private var showAddCategoryAlert = false
    @State private var showSettingsSheet = false
    @State private var showGlobalPartsBin = false
    @State private var newCategoryName = ""
    @State private var selectedCategory: String = "All"
    
    @State private var headerTitle = "Fleet Manifest"
    @AppStorage("appBackgroundTheme") private var appBackgroundTheme: String = "OLED Black"

    private var sidebarSelection: Binding<String?> {
        Binding(
            get: { selectedCategory },
            set: { selectedCategory = $0 ?? "All" }
        )
    }

    // Smart Icon Matcher for the Sidebar
    private func iconForCategory(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("phone") || lower.contains("mobile") { return "iphone" }
        if lower.contains("mac") || lower.contains("computer") || lower.contains("pc") || lower.contains("laptop") { return "desktopcomputer" }
        if lower.contains("handheld") || lower.contains("game") || lower.contains("console") { return "gamecontroller.fill" }
        if lower.contains("tv") || lower.contains("monitor") || lower.contains("display") { return "tv.fill" }
        if lower.contains("tablet") || lower.contains("pad") { return "ipad" }
        if lower.contains("watch") || lower.contains("wearable") { return "applewatch" }
        if lower.contains("audio") || lower.contains("sound") || lower.contains("music") { return "headphones" }
        if lower.contains("art") || lower.contains("draw") { return "paintpalette.fill" }
        if lower.contains("server") || lower.contains("node") { return "server.rack" }
        return "folder.fill" // Standard fallback
    }

    var body: some View {
        Group {
            #if os(macOS) || targetEnvironment(macCatalyst)
            // ==========================================
            // DESKTOP LAYOUT (SIDEBAR)
            // ==========================================
            NavigationSplitView {
                List(selection: sidebarSelection) {
                    Label("All Fleet", systemImage: "tray.2.fill").tag("All")
                    
                    if !categories.isEmpty {
                        Section(header: Text("Device Types")) {
                            ForEach(categories, id: \.self) { category in
                                Label(category, systemImage: iconForCategory(category)).tag(category)
                            }
                        }
                    }
                }
                .navigationTitle("Manifest")
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(action: { showSettingsSheet.toggle() }) { Image(systemName: "gearshape.fill").foregroundColor(.gray) }
                    }
                }
            } detail: {
                NavigationStack {
                    ZStack {
                        (appBackgroundColors[appBackgroundTheme] ?? .black).edgesIgnoringSafeArea(.all)
                        
                        if categories.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "shippingbox.fill").font(.system(size: 60)).foregroundColor(.gray.opacity(0.5))
                                Text("Fleet Manifest Initialization").font(.title2).foregroundColor(.gray)
                                Text("Awaiting first structural category.").font(.subheadline).foregroundColor(.gray.opacity(0.7))
                                Button { showAddCategoryAlert.toggle() } label: { Label("Create First Fleet Category", systemImage: "folder.badge.plus") }
                                .buttonStyle(.borderedProminent)
                                .tint(.cyan)
                                .padding(.top, 8)
                            }.padding()
                        } else {
                            VStack(spacing: 0) { deviceListSection() }
                        }
                    }
                    .navigationTitle(selectedCategory == "All" ? headerTitle : selectedCategory)
                    .toolbarBackground(appBackgroundColors[appBackgroundTheme] ?? .black, for: .navigationBar)
                    .toolbarBackground(.visible, for: .navigationBar)
                    .toolbarColorScheme(.dark, for: .navigationBar)
                    .toolbar { desktopToolbar() }
                    .navigationDestination(for: String.self) { deviceId in
                        if let index = devices.firstIndex(where: { $0.id == deviceId }) {
                            DeviceDetailFocusView(device: $devices[index], allDevices: $devices)
                        }
                    }
                }
            }
            #else
            // ==========================================
            // MOBILE LAYOUT (SEGMENTED TABS)
            // ==========================================
            NavigationStack {
                ZStack {
                    (appBackgroundColors[appBackgroundTheme] ?? .black).edgesIgnoringSafeArea(.all)
                    
                    Group {
                        if categories.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "shippingbox.fill").font(.system(size: 60)).foregroundColor(.gray.opacity(0.5))
                                Text("Fleet Manifest Initialization").font(.title2).foregroundColor(.gray)
                                Text("Awaiting first structural category.").font(.subheadline).foregroundColor(.gray.opacity(0.7))
                                Button { showAddCategoryAlert.toggle() } label: { Label("Create First Fleet Category", systemImage: "folder.badge.plus") }
                                .buttonStyle(.borderedProminent)
                                .tint(.cyan)
                                .padding(.top, 8)
                            }.padding()
                        } else {
                            VStack(spacing: 0) {
                                Picker("Category Filter", selection: $selectedCategory) {
                                    Text("All Fleet").tag("All")
                                    ForEach(categories, id: \.self) { category in Text(category).tag(category) }
                                }
                                .pickerStyle(.segmented)
                                .padding()
                                
                                deviceListSection()
                            }
                        }
                    }
                }
                .navigationTitle(headerTitle)
                .toolbarBackground(appBackgroundColors[appBackgroundTheme] ?? .black, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
                .toolbar { mobileToolbar() }
                .navigationDestination(for: String.self) { deviceId in
                    if let index = devices.firstIndex(where: { $0.id == deviceId }) {
                        DeviceDetailFocusView(device: $devices[index], allDevices: $devices)
                    }
                }
            }
            #endif
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showAddDeviceSheet) { AddDeviceFormContainer(devices: $devices, categories: categories, showAddSheet: $showAddDeviceSheet, initialCategory: selectedCategory == "All" ? categories.first ?? "" : selectedCategory) }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView(devices: $devices, globalParts: $globalParts, categories: $categories) {
                saveAllDevices()
                saveCategoriesToDisk()
                if let encodedParts = try? JSONEncoder().encode(globalParts) { UserDefaults.standard.set(encodedParts, forKey: "fleet_global_parts_bin") }
            }
        }
        .sheet(isPresented: $showGlobalPartsBin) { GlobalPartsBinView(globalParts: $globalParts, devices: $devices) }
        .alert("New Custom Category", isPresented: $showAddCategoryAlert) {
            TextField("Folder Name", text: $newCategoryName); Button("Cancel", role: .cancel) { newCategoryName = "" }
            Button("Create") {
                let trimmed = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty && !categories.contains(trimmed) { categories.append(trimmed); saveCategoriesToDisk(); selectedCategory = trimmed }
                newCategoryName = ""
            }
        }
        .onAppear { loadDataFromDisk(); rollForEasterEgg() }
    }
    
    private func rollForEasterEgg() {
        let roll = Int.random(in: 1...100)
        if roll <= 15 {
            let alternateTitles = ["Diagnostic Mode", "System Nominal", "Terminal Active", "Rivenmark Uplink", "Workbench Protocol"]
            headerTitle = alternateTitles.randomElement() ?? "Fleet Manifest"
        } else { headerTitle = "Fleet Manifest" }
    }
    
    @ViewBuilder
    private func deviceListSection() -> some View {
        let filtered = devices.filter { device in
            let matchesTab = selectedCategory == "All" || device.category == selectedCategory
            let matchesSearch = searchText.isEmpty || device.id.localizedCaseInsensitiveContains(searchText) || device.model.localizedCaseInsensitiveContains(searchText) || device.serialNumber.localizedCaseInsensitiveContains(searchText)
            return matchesTab && matchesSearch
        }
        
        List {
            if filtered.isEmpty {
                Text(selectedCategory == "All" ? "No hardware logs located in your fleet." : "No hardware logs located in \(selectedCategory).").font(.footnote).foregroundColor(.gray).italic().listRowBackground(Color.clear)
            } else {
                ForEach(filtered) { device in
                    NavigationLink(value: device.id) { SimpleDeviceRow(device: device) }.listRowBackground(Color(white: 0.1))
                }
                .onDelete(perform: removeDevice)
            }
        }
        .scrollContentBackground(.hidden)
        .searchable(text: $searchText, prompt: "Search hardware arrays...")
    }
    
    @ToolbarContentBuilder
    private func desktopToolbar() -> some ToolbarContent {
        if !categories.isEmpty {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 16) {
                    Button(action: { showAddDeviceSheet.toggle() }) {
                        Image(systemName: "plus")
                            .font(.title3.weight(.bold))
                            .foregroundColor(.cyan)
                    }
                    
                    Menu {
                        Button(action: { showGlobalPartsBin.toggle() }) { Label("Global Parts Bin", systemImage: "tray.full.fill") }
                        Button(action: { showAddCategoryAlert.toggle() }) { Label("New Category Tab", systemImage: "folder.badge.plus") }
                        Divider()
                        if selectedCategory != "All" { Button(role: .destructive, action: deleteCurrentCategory) { Label("Delete Current Category", systemImage: "trash") } }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title3)
                            .foregroundColor(.cyan)
                    }
                }
            }
        }
    }
    
    @ToolbarContentBuilder
    private func mobileToolbar() -> some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: { showSettingsSheet.toggle() }) {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.gray)
            }
        }
        
        if !categories.isEmpty {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 16) {
                    Button(action: { showAddDeviceSheet.toggle() }) {
                        Image(systemName: "plus")
                            .font(.title3.weight(.bold))
                            .foregroundColor(.cyan)
                    }
                    
                    Menu {
                        Button(action: { showGlobalPartsBin.toggle() }) { Label("Global Parts Bin", systemImage: "tray.full.fill") }
                        Button(action: { showAddCategoryAlert.toggle() }) { Label("New Category Tab", systemImage: "folder.badge.plus") }
                        Divider()
                        if selectedCategory != "All" { Button(role: .destructive, action: deleteCurrentCategory) { Label("Delete Current Category", systemImage: "trash") } }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title3)
                            .foregroundColor(.cyan)
                    }
                }
            }
        }
    }
    
    private func saveAllDevices() {
        if let encoded = try? JSONEncoder().encode(devices) { UserDefaults.standard.set(encoded, forKey: "fleet_manifest_storage_v2") }
    }
    
    private func saveCategoriesToDisk() {
        UserDefaults.standard.set(categories, forKey: "fleet_custom_categories_v2")
    }
    
    private func deleteCurrentCategory() {
        categories.removeAll { $0 == selectedCategory }; devices.removeAll { $0.category == selectedCategory }
        saveCategoriesToDisk(); saveAllDevices(); selectedCategory = "All"
    }
    
    private func removeDevice(at offsets: IndexSet) {
        let filteredDevices = devices.filter { selectedCategory == "All" || $0.category == selectedCategory }
        let devicesToDelete = offsets.map { filteredDevices[$0] }
        for target in devicesToDelete { devices.removeAll { $0.id == target.id } }
        saveAllDevices()
    }
    
    private func loadDataFromDisk() {
        if let storedCats = UserDefaults.standard.stringArray(forKey: "fleet_custom_categories_v2") {
            self.categories = storedCats; if selectedCategory.isEmpty { self.selectedCategory = "All" }
        }
        if let storedData = UserDefaults.standard.data(forKey: "fleet_manifest_storage_v2"), let decoded = try? JSONDecoder().decode([Device].self, from: storedData) {
            self.devices = decoded
        }
        var categoriesUpdated = false
        for device in self.devices {
            if !self.categories.contains(device.category) { self.categories.append(device.category); categoriesUpdated = true }
        }
        if categoriesUpdated { saveCategoriesToDisk() }
        
        if let partsData = UserDefaults.standard.data(forKey: "fleet_global_parts_bin"), let decodedParts = try? JSONDecoder().decode([Part].self, from: partsData) {
            self.globalParts = decodedParts
        }
    }
}

// --- 3. GLOBAL PARTS BIN VIEW ---
struct GlobalPartsBinView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var globalParts: [Part]
    @Binding var devices: [Device]
    
    @State private var showAddPart = false
    @State private var inspectedPart: Part?

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Total Bench Inventory Value")) {
                    let totalVal = globalParts.reduce(0) { $0 + $1.cost }
                    Text(String(format: "$%.2f", totalVal)).font(.title2).fontWeight(.bold).foregroundColor(.green)
                }
                
                Section("Loose Inventory") {
                    if globalParts.isEmpty { Text("Bench is empty.").foregroundColor(.gray).italic() }
                    ForEach(globalParts) { part in
                        Button(action: { inspectedPart = part }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(part.name).foregroundColor(.white)
                                    Text(part.serialNumber).font(.caption).foregroundColor(.gray)
                                }
                                Spacer()
                                Text(String(format: "$%.2f", part.cost)).foregroundColor(.gray)
                            }
                        }
                    }
                    .onDelete(perform: deletePart)
                }
            }
            .navigationTitle("Parts Bin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) { Button(action: { showAddPart.toggle() }) { Image(systemName: "plus") } }
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
            .sheet(isPresented: $showAddPart) {
                AddPartForm { newPart in
                    globalParts.append(newPart)
                    saveGlobalParts()
                }
            }
            .sheet(item: $inspectedPart) { part in PartDetailInspector(part: part, devices: $devices, globalParts: $globalParts) }
        }
        .preferredColorScheme(.dark)
    }
    
    private func saveGlobalParts() {
        if let encoded = try? JSONEncoder().encode(globalParts) { UserDefaults.standard.set(encoded, forKey: "fleet_global_parts_bin") }
    }
    
    private func deletePart(at offsets: IndexSet) {
        globalParts.remove(atOffsets: offsets)
        saveGlobalParts()
    }
}

// --- 4. PART DETAIL INSPECTOR & TRANSFER PROTOCOL ---
struct PartDetailInspector: View {
    let part: Part
    @Binding var devices: [Device]
    @Binding var globalParts: [Part]
    
    @Environment(\.dismiss) var dismiss
    @State private var targetDeviceID: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Component Identification") {
                    LabeledContent("Name", value: part.name)
                    LabeledContent("Serial / Batch") { Text(part.serialNumber.isEmpty ? "N/A" : part.serialNumber).font(.system(.body, design: .monospaced)) }
                }
                Section("Financials") {
                    LabeledContent("Cost", value: String(format: "$%.2f", part.cost)).foregroundColor(.green)
                }
                if !part.notes.isEmpty {
                    Section("Internal Notes") { Text(part.notes).font(.subheadline).foregroundColor(.gray) }
                }
                Section("Install to Fleet") {
                    Picker("Target Node", selection: $targetDeviceID) {
                        Text("Select Device").tag("")
                        ForEach(devices) { device in Text(device.id).tag(device.id) }
                    }
                    Button("Transfer Component") { executeTransfer() }
                    .foregroundColor(targetDeviceID.isEmpty ? .gray : .cyan)
                    .disabled(targetDeviceID.isEmpty)
                }
            }
            .navigationTitle("Component Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }
    
    private func executeTransfer() {
        if let idx = devices.firstIndex(where: { $0.id == targetDeviceID }) {
            devices[idx].installedParts.append(part)
        }
        globalParts.removeAll { $0.id == part.id }
        
        if let encodedDevices = try? JSONEncoder().encode(devices) { UserDefaults.standard.set(encodedDevices, forKey: "fleet_manifest_storage_v2") }
        if let encodedParts = try? JSONEncoder().encode(globalParts) { UserDefaults.standard.set(encodedParts, forKey: "fleet_global_parts_bin") }
        dismiss()
    }
}

// --- 5. REUSABLE ADD PART FORM ---
struct AddPartForm: View {
    @Environment(\.dismiss) var dismiss
    var onSave: (Part) -> Void

    @State private var name = ""; @State private var serial = ""; @State private var costString = ""; @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Part Details") { TextField("Component Name", text: $name); TextField("Serial / Batch Number", text: $serial) }
                Section("Financials") { TextField("Cost (USD)", text: $costString).keyboardType(.decimalPad) }
                Section("Notes") { TextField("Internal Notes", text: $notes, axis: .vertical) }
            }
            .navigationTitle("Log Component")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let cost = Double(costString.replacingOccurrences(of: "$", with: "")) ?? 0.0
                        onSave(Part(name: name, serialNumber: serial, cost: cost, notes: notes)); dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// --- 6. SETTINGS & ABOUT COMPONENT (WITH IMPORT/EXPORT) ---
struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("appBackgroundTheme") private var appBackgroundTheme: String = "OLED Black"
    
    @Binding var devices: [Device]
    @Binding var globalParts: [Part]
    @Binding var categories: [String]
    var onDataImported: () -> Void
    
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var importError = false
    @State private var showWipeConfirmation = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Appearance")) {
                    Picker("Environment Color", selection: $appBackgroundTheme) {
                        ForEach(Array(appBackgroundColors.keys.sorted()), id: \.self) { colorName in
                            HStack { Circle().fill(appBackgroundColors[colorName] ?? .black).frame(width: 12, height: 12); Text(colorName) }.tag(colorName)
                        }
                    }
                }
                
                Section(header: Text("Data Management")) {
                    Button("Export Manifest") { showExporter = true }.foregroundColor(.cyan)
                    Button("Import Manifest") { showImporter = true }.foregroundColor(.orange)
                    Button("Erase All Data", role: .destructive) { showWipeConfirmation = true }
                }
                
                Section(header: Text("About")) {
                    LabeledContent("Application", value: "Fleet Manifest")
                    LabeledContent("Manifest Version", value: "1.0")
                    LabeledContent("Developer", value: "Mario Tilley")
                    LabeledContent("Architecture", value: "Native SwiftUI")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            
            .fileExporter(
                isPresented: $showExporter,
                document: ManifestDocument(backup: FleetBackup(devices: devices, globalParts: globalParts, categories: categories)),
                contentType: .json,
                defaultFilename: "FleetManifest_Backup"
            ) { result in
                switch result {
                case .success(let url): print("Exported successfully to \(url)")
                case .failure(let error): print("Export failed: \(error.localizedDescription)")
                }
            }
            
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                do {
                    guard let selectedFile = try result.get().first else { return }
                    if selectedFile.startAccessingSecurityScopedResource() {
                        let data = try Data(contentsOf: selectedFile)
                        let importedBackup = try JSONDecoder().decode(FleetBackup.self, from: data)
                        
                        devices = importedBackup.devices
                        globalParts = importedBackup.globalParts
                        categories = importedBackup.categories
                        onDataImported()
                        
                        selectedFile.stopAccessingSecurityScopedResource()
                        dismiss()
                    }
                } catch {
                    importError = true
                    print("Import failed: \(error.localizedDescription)")
                }
            }
            .alert("Import Failed", isPresented: $importError) {
                Button("OK", role: .cancel) { }
            } message: { Text("The selected file is invalid or corrupted.") }
            .alert("Erase All Fleet Data?", isPresented: $showWipeConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Erase", role: .destructive) {
                    devices.removeAll()
                    globalParts.removeAll()
                    categories.removeAll()
                    UserDefaults.standard.removeObject(forKey: "fleet_manifest_storage_v2")
                    UserDefaults.standard.removeObject(forKey: "fleet_custom_categories_v2")
                    UserDefaults.standard.removeObject(forKey: "fleet_global_parts_bin")
                }
            } message: {
                Text("This action cannot be undone. All devices and parts will be permanently deleted.")
            }
        }
        .preferredColorScheme(.dark)
    }
}

// --- 7. ADD DEVICE FORM CONTAINER ---
struct AddDeviceFormContainer: View {
    @Binding var devices: [Device]
    var categories: [String]
    @Binding var showAddSheet: Bool
    
    @State private var showCameraScanner = false
    @State private var id = ""; @State private var category: String; @State private var manufacturer = ""
    @State private var model = ""; @State private var serialNumber = ""; @State private var osVersion = ""
    @State private var processor = ""; @State private var gpu = ""; @State private var ram = ""
    @State private var storage = ""; @State private var year = ""; @State private var notes = ""
    @State private var badgeColor = "Cyan"; @State private var status: DeviceStatus = .operational

    init(devices: Binding<[Device]>, categories: [String], showAddSheet: Binding<Bool>, initialCategory: String) {
        self._devices = devices; self.categories = categories; self._showAddSheet = showAddSheet; self._category = State(initialValue: initialCategory)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Classification") {
                    TextField("ID Name (Unique)", text: $id)
                    Picker("Status", selection: $status) { ForEach(DeviceStatus.allCases, id: \.self) { stat in Text(stat.rawValue).tag(stat) } }
                    Picker("Destination Folder Tab", selection: $category) { ForEach(categories, id: \.self) { cat in Text(cat).tag(cat) } }
                    Picker("Label Accent Color", selection: $badgeColor) {
                        ForEach(Array(themeColors.keys.sorted()), id: \.self) { colorName in
                            HStack { Circle().fill(themeColors[colorName] ?? .gray).frame(width: 12, height: 12); Text(colorName) }.tag(colorName)
                        }
                    }
                }
                Section("Specifications") {
                    TextField("Manufacturer", text: $manufacturer); TextField("Model", text: $model)
                    HStack {
                        TextField("Serial Number", text: $serialNumber)
                        #if os(iOS) && !targetEnvironment(macCatalyst)
                        if AppConfig.isScannerAvailable {
                            Button { showCameraScanner.toggle() } label: { Image(systemName: "camera.viewfinder").fontWeight(.bold) }.buttonStyle(.plain).foregroundColor(.cyan)
                        }
                        #endif
                    }
                    TextField("OS Version", text: $osVersion)
                }
                Section("Hardware Components") { TextField("Processor", text: $processor); TextField("GPU", text: $gpu); TextField("RAM", text: $ram); TextField("Storage", text: $storage); TextField("Year of Release", text: $year) }
                Section("System Notes") { TextField("Internal Notes / Mod Logs", text: $notes, axis: .vertical) }
            }
            .navigationTitle("Log New Item")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showAddSheet = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let newDevice = Device(
                            id: id, category: category, manufacturer: manufacturer, model: model, serialNumber: serialNumber, osVersion: osVersion, processor: processor,
                            gpu: gpu, ram: ram, storage: storage, year: year, notes: notes, badgeColor: badgeColor, installedParts: [], status: status
                        )
                        devices.append(newDevice)
                        if let encoded = try? JSONEncoder().encode(devices) { UserDefaults.standard.set(encoded, forKey: "fleet_manifest_storage_v2") }
                        showAddSheet = false
                    }
                    .disabled(id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || category.isEmpty)
                }
            }
            .sheet(isPresented: $showCameraScanner) {
                #if os(iOS) && !targetEnvironment(macCatalyst)
                CameraScannerView(scannedText: $serialNumber, isPresented: $showCameraScanner).edgesIgnoringSafeArea(.all)
                #else
                EmptyView()
                #endif
            }
        }
        .preferredColorScheme(.dark)
    }
}

// --- 8. INLINE ROW DISPLAY ---
struct SimpleDeviceRow: View {
    let device: Device
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Circle().fill(device.status.color).frame(width: 8, height: 8)
                Text(device.id).font(.headline).foregroundColor(.white)
                Spacer()
                Text(device.category.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background((themeColors[device.badgeColor] ?? .gray).opacity(0.2))
                    .cornerRadius(4).foregroundColor(themeColors[device.badgeColor] ?? .gray)
            }
            Text("\(device.manufacturer) \(device.model)").font(.subheadline).foregroundColor(.gray)
        }
        .padding(.vertical, 4)
    }
}

// --- 9. DETAIL FOCUS INSPECTION VIEW ---
struct DeviceDetailFocusView: View {
    @Binding var device: Device
    @Binding var allDevices: [Device]
    
    @Environment(\.dismiss) var dismiss
    @State private var isEditing = false
    @State private var showDetailScanner = false
    @State private var showAddPartSheet = false
    @State private var inspectedPart: Part?
    
    @State private var editID = ""; @State private var editCategory = ""; @State private var editManufacturer = ""
    @State private var editModel = ""; @State private var editSerial = ""; @State private var editOS = ""
    @State private var editProcessor = ""; @State private var editGPU = ""; @State private var editRAM = ""
    @State private var editStorage = ""; @State private var editYear = ""; @State private var editNotes = ""
    @State private var editBadgeColor = ""; @State private var editStatus: DeviceStatus = .operational
    
    var body: some View {
        Form {
            if isEditing {
                Section("Classification") {
                    TextField("Device Name ID", text: $editID)
                    Picker("Status", selection: $editStatus) { ForEach(DeviceStatus.allCases, id: \.self) { stat in Text(stat.rawValue).tag(stat) } }
                    TextField("Category Target", text: $editCategory).disabled(true)
                    Picker("Label Accent Color", selection: $editBadgeColor) {
                        ForEach(Array(themeColors.keys.sorted()), id: \.self) { colorName in
                            HStack { Circle().fill(themeColors[colorName] ?? .gray).frame(width: 12, height: 12); Text(colorName) }.tag(colorName)
                        }
                    }
                }
                Section("Specifications") {
                    TextField("Manufacturer", text: $editManufacturer); TextField("Model", text: $editModel)
                    HStack {
                        TextField("Serial Number", text: $editSerial)
                        #if os(iOS) && !targetEnvironment(macCatalyst)
                        if AppConfig.isScannerAvailable {
                            Button { showDetailScanner.toggle() } label: { Image(systemName: "camera.viewfinder").fontWeight(.bold) }.buttonStyle(.plain).foregroundColor(.cyan)
                        }
                        #endif
                    }
                    TextField("OS Version", text: $editOS)
                }
                Section("Hardware Components") { TextField("Processor", text: $editProcessor); TextField("GPU", text: $editGPU); TextField("RAM", text: $editRAM); TextField("Storage", text: $editStorage); TextField("Year of Release", text: $editYear) }
                Section("System Notes") { TextField("Internal Notes", text: $editNotes, axis: .vertical) }
            } else {
                Section("Classification") {
                    LabeledContent("Alias", value: device.id)
                    LabeledContent("Status") { Text(device.status.rawValue).foregroundColor(device.status.color).fontWeight(.medium) }
                    LabeledContent("Category Tab", value: device.category)
                    LabeledContent("Accent Profile") { Circle().fill(themeColors[device.badgeColor] ?? .gray).frame(width: 12, height: 12) }
                }
                Section("Specifications") {
                    LabeledContent("Manufacturer", value: device.manufacturer); LabeledContent("Model", value: device.model)
                    LabeledContent("Serial Number") { Text(device.serialNumber.isEmpty ? "N/A" : device.serialNumber).font(.system(.body, design: .monospaced)) }
                    LabeledContent("OS Version", value: device.osVersion.isEmpty ? "N/A" : device.osVersion)
                }
                
                Section(header: Text("Financials & Installed Parts")) {
                    let parts = device.installedParts
                    let totalSunk = parts.reduce(0) { $0 + $1.cost }
                    LabeledContent("Total Parts Investment") { Text(String(format: "$%.2f", totalSunk)).fontWeight(.bold).foregroundColor(totalSunk > 0 ? .green : .gray) }
                    if !parts.isEmpty {
                        ForEach(parts) { part in
                            Button(action: { inspectedPart = part }) {
                                HStack {
                                    VStack(alignment: .leading) { Text(part.name).foregroundColor(.white); Text(part.serialNumber).font(.caption).foregroundColor(.gray) }
                                    Spacer(); Text(String(format: "$%.2f", part.cost)).foregroundColor(.gray)
                                }
                            }
                        }
                        .onDelete(perform: deleteInstalledPart)
                    }
                    Button(action: { showAddPartSheet.toggle() }) { Label("Log Installed Component", systemImage: "plus.app").foregroundColor(.cyan) }
                }
                
                Section("Core Internals") {
                    LabeledContent("Processor", value: device.processor.isEmpty ? "N/A" : device.processor); LabeledContent("GPU", value: device.gpu.isEmpty ? "N/A" : device.gpu)
                    LabeledContent("RAM", value: device.ram.isEmpty ? "N/A" : device.ram); LabeledContent("Storage", value: device.storage.isEmpty ? "N/A" : device.storage)
                    LabeledContent("Year", value: device.year.isEmpty ? "N/A" : device.year)
                }
                if !device.notes.isEmpty { Section("System Notes") { Text(device.notes).font(.subheadline).foregroundColor(.gray).italic() } }
            }
        }
        .navigationTitle(isEditing ? "Edit Spec Folder" : device.id)
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItemGroup(placement: .confirmationAction) {
                Button(isEditing ? "Apply Changes" : "Edit Details") { if isEditing { applyModifiedNodeEdits() } else { populateFormFields(); isEditing = true } }
            }
        }
        .sheet(isPresented: $showDetailScanner) {
            #if os(iOS) && !targetEnvironment(macCatalyst)
            CameraScannerView(scannedText: $editSerial, isPresented: $showDetailScanner).edgesIgnoringSafeArea(.all)
            #else
            EmptyView()
            #endif
        }
        .sheet(isPresented: $showAddPartSheet) { AddPartForm { newPart in addInstalledPart(newPart) } }
        .sheet(item: $inspectedPart) { part in PartDetailInspector(part: part, devices: .constant([]), globalParts: .constant([])) }
    }
    
    private func addInstalledPart(_ part: Part) {
        device.installedParts.append(part)
        if let idx = allDevices.firstIndex(where: { $0.id == device.id }) {
            allDevices[idx] = device
            saveAllDevices()
        }
    }
    
    private func deleteInstalledPart(at offsets: IndexSet) {
        device.installedParts.remove(atOffsets: offsets)
        if let idx = allDevices.firstIndex(where: { $0.id == device.id }) {
            allDevices[idx] = device
            saveAllDevices()
        }
    }
    
    private func saveAllDevices() {
        if let encoded = try? JSONEncoder().encode(allDevices) { UserDefaults.standard.set(encoded, forKey: "fleet_manifest_storage_v2") }
    }
    
    private func populateFormFields() {
        editID = device.id; editCategory = device.category; editManufacturer = device.manufacturer; editModel = device.model
        editSerial = device.serialNumber; editOS = device.osVersion; editProcessor = device.processor; editGPU = device.gpu
        editRAM = device.ram; editStorage = device.storage; editYear = device.year; editNotes = device.notes; editBadgeColor = device.badgeColor; editStatus = device.status
    }
    
    private func applyModifiedNodeEdits() {
        device = Device(
            id: editID, category: editCategory, manufacturer: editManufacturer, model: editModel, serialNumber: editSerial, osVersion: editOS, processor: editProcessor,
            gpu: editGPU, ram: editRAM, storage: editStorage, year: editYear, notes: editNotes, badgeColor: editBadgeColor, installedParts: device.installedParts, status: editStatus
        )
        if let idx = allDevices.firstIndex(where: { $0.id == device.id }) {
            allDevices[idx] = device
            saveAllDevices()
        }
        isEditing = false
        dismiss()
    }
}

// --- 10. MOBILE OPTICAL CHARACTER RECOGNITION VIEW ---
#if os(iOS) && !targetEnvironment(macCatalyst)
struct CameraScannerView: UIViewControllerRepresentable {
    @Binding var scannedText: String; @Binding var isPresented: Bool
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(recognizedDataTypes: [.text()], qualityLevel: .balanced, recognizesMultipleItems: false, isHighFrameRateTrackingEnabled: true, isHighlightingEnabled: true)
        scanner.delegate = context.coordinator; return scanner
    }
    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) { try? uiViewController.startScanning() }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var parent: CameraScannerView; init(_ parent: CameraScannerView) { self.parent = parent }
        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            switch item {
            case .text(let text): parent.scannedText = text.transcript.trimmingCharacters(in: .whitespacesAndNewlines); parent.isPresented = false
            default: break
            }
        }
    }
}
#endif // os(iOS) && !targetEnvironment(macCatalyst)
