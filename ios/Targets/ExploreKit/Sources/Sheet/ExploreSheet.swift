import SwiftUI

extension PresentationDetent {
    static let peek = PresentationDetent.height(84)
    static let half = PresentationDetent.fraction(0.44)
}

struct ExploreSheet: View {
    @Bindable var store: ExploreStore
    @Binding var detent: PresentationDetent
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if let place = store.selectedPlace {
                PlaceDetailView(store: store, place: place)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else if let event = store.selectedEvent {
                EventDetailView(store: store, event: event)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 18)
                    .padding(.bottom, 12)
                ScrollView {
                    if detent == .peek {
                        EmptyView()
                    } else if store.isSearching {
                        SearchResultsView(store: store)
                    } else {
                        HomeContent(store: store)
                    }
                }
                .scrollDismissesKeyboard(.immediately)
                .scrollIndicators(.hidden)
            }
        }
        .animation(.snappy(duration: 0.3), value: store.selection)
        .onChange(of: searchFocused) { _, focused in
            if focused { detent = .large }
        }
        .onChange(of: store.selection) { _, selection in
            if selection != nil {
                searchFocused = false
                if detent == .peek { detent = .half }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
                TextField("Search spots & events", text: $store.query)
                    .focused($searchFocused)
                    .submitLabel(.search)
                    .font(.system(.body, design: .rounded))
                if store.isSearching {
                    Button {
                        store.query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                } else {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(Capsule().fill(.black.opacity(0.06)))

            if searchFocused {
                Button("Cancel") {
                    store.query = ""
                    searchFocused = false
                    detent = .half
                }
                .font(.system(.body, design: .rounded, weight: .semibold))
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                Text("S")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(LinearGradient(colors: [Palette.orange, Palette.pink], startPoint: .topLeading, endPoint: .bottomTrailing)))
                    .overlay(Circle().strokeBorder(.white, lineWidth: 2))
            }
        }
        .animation(.snappy, value: searchFocused)
    }
}

struct HomeContent: View {
    @Bindable var store: ExploreStore

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Filter.all) { filter in
                        FilterChip(filter: filter, isOn: store.filter == filter) {
                            store.filter = store.filter == filter ? nil : filter
                        }
                    }
                }
                .padding(.horizontal, 16)
            }

            if store.filter == nil || store.filter == .events {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "This week in Frankfurt", caption: "Sample events")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(store.upcomingEvents) { event in
                                Button {
                                    store.selection = .event(event.id)
                                } label: {
                                    EventCard(event: event, isPlanned: store.plannedEventIDs.contains(event.id))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 6)
                    }
                }
            }

            if store.filter != .events {
                let list = listPlaces
                VStack(alignment: .leading, spacing: 4) {
                    SectionHeader(title: listTitle, caption: "\(list.count)")
                        .padding(.bottom, 4)
                    ForEach(list) { place in
                        Button {
                            store.selection = .place(place.id)
                        } label: {
                            PlaceRow(place: place)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if store.filter == nil {
                AddFromLinkCard()
                    .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 40)
    }

    private var listPlaces: [Place] {
        switch store.filter {
        case .none: store.savedPlaces
        default: store.visiblePlaces
        }
    }

    private var listTitle: String {
        switch store.filter {
        case .none, .saved: "Your spots"
        case .events: ""
        case .category(let c): c.title
        }
    }
}

struct AddFromLinkCard: View {
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: [.black, Color(red: 0.86, green: 0.19, blue: 0.47)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "square.and.arrow.down.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 46, height: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text("Save from TikTok or Instagram")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                Text("Share a video to Spots and we'll pin the place. Coming in the next build.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.7)))
    }
}

struct SearchResultsView: View {
    @Bindable var store: ExploreStore

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            let places = store.searchPlaces
            let events = store.searchEvents
            if places.isEmpty && events.isEmpty {
                ContentUnavailableView.search(text: store.query)
                    .padding(.top, 30)
            }
            if !places.isEmpty {
                SectionHeader(title: "Places").padding(.bottom, 4)
                ForEach(places) { place in
                    Button { store.selection = .place(place.id) } label: { PlaceRow(place: place) }
                        .buttonStyle(.plain)
                }
            }
            if !events.isEmpty {
                SectionHeader(title: "Events").padding(.top, 12).padding(.bottom, 4)
                ForEach(events) { event in
                    Button { store.selection = .event(event.id) } label: {
                        HStack(spacing: 12) {
                            IconBadge(symbol: event.symbol, tint: event.tint, size: 40)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(event.title).font(.system(.body, design: .rounded, weight: .semibold))
                                Text("\(event.start.formatted(.dateTime.weekday(.wide).hour().minute())) · \(event.venue)")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20).padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.bottom, 40)
    }
}
