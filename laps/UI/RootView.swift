import SwiftUI

struct RootView: View {
    @Environment(WalkStore.self) private var store
    @Environment(PhotoStore.self) private var photos
    @Environment(\.scenePhase) private var scenePhase
    #if DEBUG
    // Debug-only: `-startTab N` opens a given tab (used for screenshots).
    @State private var tab = UserDefaults.standard.integer(forKey: "startTab")
    #else
    @State private var tab = 0
    #endif

    var body: some View {
        TabView(selection: $tab) {
            TodayView()
                .tabItem { Label("Today", systemImage: "figure.walk") }
                .tag(0)
            NavigationStack { WeekView() }
                .tabItem { Label("This Week", systemImage: "chart.bar.fill") }
                .tag(1)
            NavigationStack { EverydayView() }
                .tabItem { Label("Everyday", systemImage: "car.fill") }
                .tag(2)
            NavigationStack { RemindersView() }
                .tabItem { Label("Reminders", systemImage: "bell.fill") }
                .tag(3)
            if photos.settings.isOn {
                NavigationStack { PictureView() }
                    .tabItem { Label("Picture", systemImage: "photo.fill") }
                    .tag(4)
            }
        }
        // The picture follows his activity wherever it's recorded, and picks a new photo each day.
        .onAppear(perform: syncPicture)
        .onChange(of: store.walkingCreditsToday) { _, _ in syncPicture() }
        .onChange(of: store.standingCreditsToday) { _, _ in syncPicture() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { syncPicture() } }   // a new day's picture
        .onChange(of: photos.settings) { _, _ in syncPicture() }
        .onChange(of: photos.activePhotos.count) { _, _ in syncPicture() }
        .tint(Theme.teal)
        .sheet(isPresented: Binding(
            get: { store.standUpPrompt != nil },
            set: { if !$0 { store.standUpPrompt = nil } }
        )) {
            if let choices = store.standUpPrompt {
                StandUpPickerView(choices: choices)
                    .environment(store)
                    .presentationDragIndicator(.visible)
            }
        }
        .onChange(of: store.standUpPrompt != nil) { _, showing in
            if showing { tab = 0 }
        }
        #if DEBUG
        .onAppear {
            // Debug-only: `-showStandUp YES` opens the stand-up picker (used for screenshots).
            if UserDefaults.standard.bool(forKey: "showStandUp") { store.showStandUpPicker() }
        }
        #endif
        .overlay(alignment: .bottom) {
            if let problem = store.loadProblem {
                Text("Couldn't read saved walks (\(problem)). A backup copy was kept.")
                    .font(.footnote)
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding()
            }
        }
    }

    private func syncPicture() {
        photos.sync(day: store.todayKey, walking: store.walkingCreditsToday, standing: store.standingCreditsToday)
    }
}
