import SwiftUI

struct RootView: View {
    @Environment(WalkStore.self) private var store
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
        }
        .tint(Theme.teal)
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
}
