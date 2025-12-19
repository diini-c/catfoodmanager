import SwiftUI

struct CatsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var appState: AppState
    @State private var showingAddCat = false
    @State private var selectedCat: Cat?
    
    var body: some View {
        NavigationView {
            Group {
                if appState.cats.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "cat")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No cats yet")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        if authManager.user?.isAdmin == true {
                            Button("Add Your First Cat") {
                                showingAddCat = true
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                        } else {
                            Text("Ask your admin to add cats")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    List {
                        ForEach(appState.cats) { cat in
                            CatRowView(cat: cat)
                                .onTapGesture {
                                    selectedCat = cat
                                }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable {
                        if let token = authManager.token {
                            await appState.loadData(token: token)
                        }
                    }
                }
            }
            .navigationTitle("Your Cats")
            .toolbar {
                if authManager.user?.isAdmin == true && !appState.cats.isEmpty {
                    Button(action: { showingAddCat = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddCat) {
                AddCatView()
            }
            .sheet(item: $selectedCat) { cat in
                CatDetailView(cat: cat)
            }
        }
    }
}

struct CatRowView: View {
    let cat: Cat
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Text(String(cat.name.prefix(1)).uppercased())
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(cat.name)
                    .font(.headline)
                
                HStack {
                    if let breed = cat.breed {
                        Text(breed)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text("\(cat.feedingSchedule.timesPerDay)x daily")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(cat.feedingSchedule.portionSize)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                
                Text(cat.feedingSchedule.scheduledTimes.joined(separator: ", "))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddCatView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var breed = ""
    @State private var notes = ""
    @State private var weight = ""
    @State private var birthDate = Date()
    @State private var hasBirthDate = false
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Info") {
                    TextField("Cat's Name", text: $name)
                    TextField("Breed (optional)", text: $breed)
                    TextField("Weight in lbs (optional)", text: $weight)
                        .keyboardType(.decimalPad)
                }
                
                Section {
                    Toggle("Add Birth Date", isOn: $hasBirthDate)
                    if hasBirthDate {
                        DatePicker("Birth Date", selection: $birthDate, displayedComponents: .date)
                    }
                }
                
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
            }
            .navigationTitle("Add Cat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addCat()
                    }
                    .disabled(name.isEmpty || isLoading)
                }
            }
        }
    }
    
    private func addCat() {
        guard let token = authManager.token else { return }
        isLoading = true
        
        let request = CreateCatRequest(
            name: name,
            breed: breed.isEmpty ? nil : breed,
            birthDate: hasBirthDate ? birthDate : nil,
            weight: Double(weight),
            notes: notes.isEmpty ? nil : notes
        )
        
        Task {
            let success = await appState.addCat(request, token: token)
            if success {
                dismiss()
            }
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

struct CatDetailView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    let cat: Cat
    
    @State private var showingFeedSheet = false
    @State private var showingScheduleEdit = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Cat avatar
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.2))
                            .frame(width: 100, height: 100)
                        
                        Text(String(cat.name.prefix(1)).uppercased())
                            .font(.system(size: 40))
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                    
                    Text(cat.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if let breed = cat.breed {
                        Text(breed)
                            .foregroundColor(.secondary)
                    }
                    
                    // Quick feed button
                    Button(action: { showingFeedSheet = true }) {
                        Label("Log Feeding", systemImage: "fork.knife")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    // Feeding schedule card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Feeding Schedule")
                                .font(.headline)
                            
                            Spacer()
                            
                            if authManager.user?.isAdmin == true {
                                Button("Edit") {
                                    showingScheduleEdit = true
                                }
                                .font(.subheadline)
                            }
                        }
                        
                        Divider()
                        
                        HStack {
                            Label("\(cat.feedingSchedule.timesPerDay)x daily", systemImage: "clock")
                            Spacer()
                            Text(cat.feedingSchedule.scheduledTimes.joined(separator: ", "))
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Label(cat.feedingSchedule.portionSize, systemImage: "scalemass")
                            Spacer()
                            Text(cat.feedingSchedule.foodType)
                                .foregroundColor(.secondary)
                        }
                        
                        if let instructions = cat.feedingSchedule.specialInstructions {
                            Divider()
                            Text(instructions)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Cat info
                    if cat.weight != nil || cat.notes != nil {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Details")
                                .font(.headline)
                            
                            Divider()
                            
                            if let weight = cat.weight {
                                HStack {
                                    Label("Weight", systemImage: "scalemass.fill")
                                    Spacer()
                                    Text("\(weight, specifier: "%.1f") lbs")
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if let notes = cat.notes {
                                Text(notes)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                }
                .padding(.top)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingFeedSheet) {
                LogFeedingView(cat: cat)
            }
            .sheet(isPresented: $showingScheduleEdit) {
                EditScheduleView(cat: cat)
            }
        }
    }
}

struct LogFeedingView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    let cat: Cat
    
    @State private var portionSize: String
    @State private var foodType: String
    @State private var notes = ""
    @State private var isLoading = false
    
    init(cat: Cat) {
        self.cat = cat
        _portionSize = State(initialValue: cat.feedingSchedule.portionSize)
        _foodType = State(initialValue: cat.feedingSchedule.foodType)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Portion") {
                    TextField("Portion Size", text: $portionSize)
                    TextField("Food Type", text: $foodType)
                }
                
                Section("Notes (optional)") {
                    TextEditor(text: $notes)
                        .frame(height: 80)
                }
            }
            .navigationTitle("Feed \(cat.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") {
                        logFeeding()
                    }
                    .disabled(isLoading)
                }
            }
        }
    }
    
    private func logFeeding() {
        guard let token = authManager.token else { return }
        isLoading = true
        
        let request = CreateFeedingLogRequest(
            catId: cat.id,
            portionSize: portionSize,
            foodType: foodType,
            notes: notes.isEmpty ? nil : notes
        )
        
        Task {
            let success = await appState.logFeeding(request, token: token)
            if success {
                dismiss()
            }
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

struct EditScheduleView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    let cat: Cat
    
    @State private var timesPerDay: Int
    @State private var portionSize: String
    @State private var foodType: String
    @State private var specialInstructions: String
    @State private var scheduledTimes: [String]
    @State private var isLoading = false
    
    init(cat: Cat) {
        self.cat = cat
        _timesPerDay = State(initialValue: cat.feedingSchedule.timesPerDay)
        _portionSize = State(initialValue: cat.feedingSchedule.portionSize)
        _foodType = State(initialValue: cat.feedingSchedule.foodType)
        _specialInstructions = State(initialValue: cat.feedingSchedule.specialInstructions ?? "")
        _scheduledTimes = State(initialValue: cat.feedingSchedule.scheduledTimes)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Feeding Times") {
                    Stepper("Times per day: \(timesPerDay)", value: $timesPerDay, in: 1...6)
                        .onChange(of: timesPerDay) { newValue in
                            adjustScheduledTimes(to: newValue)
                        }
                    
                    ForEach(0..<scheduledTimes.count, id: \.self) { index in
                        TextField("Time \(index + 1)", text: $scheduledTimes[index])
                    }
                }
                
                Section("Portion") {
                    TextField("Portion Size", text: $portionSize)
                    TextField("Food Type", text: $foodType)
                }
                
                Section("Special Instructions") {
                    TextEditor(text: $specialInstructions)
                        .frame(height: 80)
                }
            }
            .navigationTitle("Edit Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSchedule()
                    }
                    .disabled(isLoading)
                }
            }
        }
    }
    
    private func adjustScheduledTimes(to count: Int) {
        while scheduledTimes.count < count {
            scheduledTimes.append("12:00")
        }
        while scheduledTimes.count > count {
            scheduledTimes.removeLast()
        }
    }
    
    private func saveSchedule() {
        guard let token = authManager.token else { return }
        isLoading = true
        
        let request = UpdateFeedingScheduleRequest(
            timesPerDay: timesPerDay,
            scheduledTimes: scheduledTimes,
            portionSize: portionSize,
            foodType: foodType,
            specialInstructions: specialInstructions.isEmpty ? nil : specialInstructions
        )
        
        Task {
            let success = await appState.updateFeedingSchedule(catId: cat.id, schedule: request, token: token)
            if success {
                dismiss()
            }
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

#Preview {
    CatsView()
        .environmentObject(AuthManager())
        .environmentObject(AppState())
}
