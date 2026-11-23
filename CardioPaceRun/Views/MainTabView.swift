import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            RunView()
                .tabItem {
                    Label("Corri", systemImage: "figure.run")
                }

            HistoryView()
                .tabItem {
                    Label("Cronologia", systemImage: "list.bullet.clipboard")
                }

            SettingsView()
                .tabItem {
                    Label("Impostazioni", systemImage: "slider.horizontal.3")
                }
        }
    }
}
