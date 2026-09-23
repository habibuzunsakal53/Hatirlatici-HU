
import SwiftUI
import UserNotifications

// MARK: - 1. VERİ MODELİ
struct ReminderItem: Identifiable, Codable {
    var id = UUID()
    var title: String
    var category: String          // "Acil 🚨" veya "Standart"
    var repeatType: String        // "Saatlik", "Günlük", "Haftalık", "Aylık"
    var selectedHour: Int = 12
    var selectedDayOfWeek: String = "Pazartesi"
    var selectedDayOfMonth: Int = 1
    var isCompleted: Bool = false
}

// MARK: - 2. ANA EKRAN
struct ContentView: View {
    @AppStorage("my_notification_reminders_v4") private var savedData: Data = Data()
    @State private var reminders: [ReminderItem] = []
    
    // Form Seçim Değişkenleri ("Acil 🚨" olarak güncellendi)
    @State private var selectedCategory: String = "Acil 🚨"
    @State private var titleInput: String = ""
    @State private var repeatTypeInput: String = "Günlük"
    @State private var hourInput: Int = 12
    @State private var dayOfWeekInput: String = "Pazartesi"
    @State private var dayOfMonthInput: Int = 1
    
    let categories = ["Acil 🚨", "Standart"]
    let repeatOptions = ["Saatlik", "Günlük", "Haftalık", "Aylık"]
    let daysOfWeek = ["Pazartesi", "Salı", "Çarşamba", "Perşembe", "Cuma", "Cumartesi", "Pazar"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // KATEGORİ SEÇİMİ
                Picker("Kategori", selection: $selectedCategory) {
                    ForEach(categories, id: \.self) { cat in
                        Text(cat).tag(cat)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // LİSTE VE FORM
                List {
                    // HATIRLATICI LİSTESİ
                    Section("Hatırlatıcılar (\(selectedCategory))") {
                        let filtered = filteredReminders
                        if filtered.isEmpty {
                            Text("Bu kategoride henüz hatırlatıcı yok.")
                                .foregroundColor(.gray)
                        } else {
                            ForEach(filtered) { item in
                                HStack {
                                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(item.isCompleted ? .green : .gray)
                                        .onTapGesture {
                                            toggleItem(item)
                                        }
                                    
                                    VStack(alignment: .leading) {
                                        Text(item.title)
                                            .strikethrough(item.isCompleted)
                                            .font(.body)
                                        
                                        Text(getDetails(for: item))
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "bell.fill")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                            .onDelete(perform: deleteItem)
                        }
                    }
                    
                    // YENİ HATIRLATICI EKLEME FORMU
                    Section("Yeni \(selectedCategory) Hatırlatıcı Ekle") {
                        TextField("Hatırlatıcı başlığını buraya yazın...", text: $titleInput)
                            .textFieldStyle(.roundedBorder)
                            .padding(.vertical, 4)
                        
                        Picker("Tekrar Sıklığı", selection: $repeatTypeInput) {
                            ForEach(repeatOptions, id: \.self) { type in
                                Text(type).tag(type)
                            }
                        }
                        
                        if repeatTypeInput != "Saatlik" {
                            Picker("Saat (24s Formatı)", selection: $hourInput) {
                                ForEach(0..<24, id: \.self) { h in
                                    Text(String(format: "%02d:00", h)).tag(h)
                                }
                            }
                        }
                        
                        if repeatTypeInput == "Haftalık" {
                            Picker("Gün Seçin", selection: $dayOfWeekInput) {
                                ForEach(daysOfWeek, id: \.self) { d in
                                    Text(d).tag(d)
                                }
                            }
                        }
                        
                        if repeatTypeInput == "Aylık" {
                            Picker("Ayın Günü (Sayı)", selection: $dayOfMonthInput) {
                                ForEach(1...31, id: \.self) { day in
                                    Text("\(day). Gün").tag(day)
                                }
                            }
                        }
                        
                        Button(action: addReminder) {
                            HStack {
                                Image(systemName: "bell.badge.fill")
                                Text("Hatırlatıcıyı & Bildirimi Kur")
                                    .bold()
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(titleInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .navigationTitle("Hatırlatıcı")
            .onAppear {
                loadData()
                requestNotificationPermission()
            }
        }
    }
    
    // MARK: - YARDIMCI FONKSİYONLAR & BİLDİRİM MANTIĞI
    
    var filteredReminders: [ReminderItem] {
        reminders.filter { $0.category == selectedCategory }
    }
    
    func addReminder() {
        let newItem = ReminderItem(
            title: titleInput,
            category: selectedCategory,
            repeatType: repeatTypeInput,
            selectedHour: hourInput,
            selectedDayOfWeek: dayOfWeekInput,
            selectedDayOfMonth: dayOfMonthInput
        )
        reminders.append(newItem)
        scheduleNotification(for: newItem)
        titleInput = ""
        saveData()
    }
    
    func toggleItem(_ item: ReminderItem) {
        if let index = reminders.firstIndex(where: { $0.id == item.id }) {
            reminders[index].isCompleted.toggle()
            saveData()
        }
    }
    
    func deleteItem(at offsets: IndexSet) {
        let targetItems = filteredReminders
        for index in offsets {
            let itemToDelete = targetItems[index]
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [itemToDelete.id.uuidString])
            reminders.removeAll(where: { $0.id == itemToDelete.id })
        }
        saveData()
    }
    
    func getDetails(for item: ReminderItem) -> String {
        let h = String(format: "%02d:00", item.selectedHour)
        switch item.repeatType {
        case "Saatlik": return "Her saat başı bildirim gönderilir"
        case "Günlük": return "Her gün Saat \(h) bildirim gönderilir"
        case "Haftalık": return "Her hafta \(item.selectedDayOfWeek) günü Saat \(h)"
        case "Aylık": return "Her ayın \(item.selectedDayOfMonth). günü Saat \(h)"
        default: return ""
        }
    }
    
    // --- BİLDİRİM (ALARM) AYARLARI ---
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Bildirim izni verildi.")
            }
        }
    }
    
    func scheduleNotification(for item: ReminderItem) {
        let content = UNMutableNotificationContent()
        content.title = "[\(item.category)] Hatırlatıcı"
        content.body = item.title
        content.sound = .default
        
        var dateComponents = DateComponents()
        
        switch item.repeatType {
        case "Saatlik":
            dateComponents.minute = 0
        case "Günlük":
            dateComponents.hour = item.selectedHour
            dateComponents.minute = 0
        case "Haftalık":
            dateComponents.hour = item.selectedHour
            dateComponents.minute = 0
            let dayIndex = (daysOfWeek.firstIndex(of: item.selectedDayOfWeek) ?? 0) + 2
            dateComponents.weekday = dayIndex > 7 ? 1 : dayIndex
        case "Aylık":
            dateComponents.hour = item.selectedHour
            dateComponents.minute = 0
            dateComponents.day = item.selectedDayOfMonth
        default:
            break
        }
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: item.id.uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func saveData() {
        if let encoded = try? JSONEncoder().encode(reminders) {
            savedData = encoded
        }
    }
    
    func loadData() {
        if let decoded = try? JSONDecoder().decode([ReminderItem].self, from: savedData) {
            reminders = decoded
        }
    }
}
