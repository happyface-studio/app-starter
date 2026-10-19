import Foundation

enum SeedData {

    static let places: [Place] = [
        Place(
            id: "kleinmarkthalle", name: "Kleinmarkthalle", category: .food, neighbourhood: "Altstadt",
            address: "Hasengasse 5–7", blurb: "Covered market hall with 150 stalls. Go hungry: Grüne Soße, Fleischwurst, cheese and wine on the gallery.",
            tags: ["Market", "Lunch", "Local classic"], priceLevel: 1, latitude: 50.112720, longitude: 8.683044,
            savedFrom: SavedFrom(source: .tiktok, caption: "The Fleischwurst queue is worth it", savedDaysAgo: 2)),
        Place(
            id: "margarete", name: "Margarete", category: .food, neighbourhood: "Altstadt",
            address: "Braubachstraße 18–22", blurb: "Bistro by day, restaurant by night, a few steps from the new old town.",
            tags: ["Dinner", "Wine"], priceLevel: 2, latitude: 50.111419, longitude: 8.683338,
            savedFrom: SavedFrom(source: .instagram, caption: "Date night spot", savedDaysAgo: 9)),
        Place(
            id: "wagner", name: "Apfelwein Wagner", category: .food, neighbourhood: "Sachsenhausen",
            address: "Schweizer Straße 71", blurb: "Long shared tables, Bembel jugs and Schnitzel with Grüne Soße. Very Frankfurt.",
            tags: ["Apfelwein", "Traditional"], priceLevel: 2, latitude: 50.100531, longitude: 8.682001,
            savedFrom: SavedFrom(source: .tiktok, caption: "Apfelwein 101", savedDaysAgo: 14)),
        Place(
            id: "gemalten-haus", name: "Zum Gemalten Haus", category: .food, neighbourhood: "Sachsenhausen",
            address: "Schweizer Straße 67", blurb: "Apfelwein tavern with painted walls and a big courtyard.",
            tags: ["Apfelwein", "Courtyard"], priceLevel: 2, latitude: 50.100707, longitude: 8.681872),
        Place(
            id: "oosten", name: "Oosten", category: .food, neighbourhood: "Ostend",
            address: "Mayfarthstraße 4", blurb: "Glass box on the river by the EZB. Sunset drinks on the terrace.",
            tags: ["Riverside", "Terrace"], priceLevel: 3, latitude: 50.107726, longitude: 8.702739,
            savedFrom: SavedFrom(source: .instagram, caption: "Sunset by the Main", savedDaysAgo: 21)),
        Place(
            id: "maintower", name: "Main Tower Restaurant", category: .food, neighbourhood: "Innenstadt",
            address: "Neue Mainzer Straße 52", blurb: "Dinner on the 53rd floor with the whole skyline below.",
            tags: ["View", "Fine dining"], priceLevel: 4, latitude: 50.112380, longitude: 8.672089),
        Place(
            id: "bitter-zart", name: "Bitter & Zart", category: .cafe, neighbourhood: "Altstadt",
            address: "Braubachstraße 14", blurb: "Chocolate shop with a tiny café. Hot chocolate and cake by the window.",
            tags: ["Chocolate", "Cake"], priceLevel: 2, latitude: 50.111497, longitude: 8.683685,
            savedFrom: SavedFrom(source: .instagram, caption: "Best hot chocolate in town?", savedDaysAgo: 4)),
        Place(
            id: "wacker", name: "Wacker's Kaffee", category: .cafe, neighbourhood: "Altstadt",
            address: "Kornmarkt 9", blurb: "Roasting since 1914. Stand-up espresso, queue out the door.",
            tags: ["Espresso", "Roastery"], priceLevel: 1, latitude: 50.112067, longitude: 8.679220),
        Place(
            id: "hoppenworth", name: "Hoppenworth & Ploch", category: .cafe, neighbourhood: "Nordend",
            address: "Friedberger Landstraße 86", blurb: "Specialty coffee roasters. Flat white and a cardamom bun.",
            tags: ["Specialty coffee", "Laptop friendly"], priceLevel: 2, latitude: 50.124809, longitude: 8.692040,
            savedFrom: SavedFrom(source: .instagram, caption: "Coffee crawl stop #1", savedDaysAgo: 6)),
        Place(
            id: "plank", name: "Plank", category: .bar, neighbourhood: "Bahnhofsviertel",
            address: "Elbestraße 15", blurb: "Café by day, bar by night. Design crowd, good playlists.",
            tags: ["Cocktails", "Coffee"], priceLevel: 2, latitude: 50.107754, longitude: 8.668529,
            savedFrom: SavedFrom(source: .tiktok, caption: "Bahnhofsviertel night out", savedDaysAgo: 1)),
        Place(
            id: "kinly", name: "Kinly Bar", category: .bar, neighbourhood: "Bahnhofsviertel",
            address: "Elbestraße 31", blurb: "Speakeasy behind an unmarked door. Ring the bell.",
            tags: ["Speakeasy", "Cocktails"], priceLevel: 3, latitude: 50.108939, longitude: 8.667221),
        Place(
            id: "naiv", name: "Naiv", category: .bar, neighbourhood: "Altstadt",
            address: "Fahrgasse 4", blurb: "Craft beer bar near the river with a rotating tap list.",
            tags: ["Craft beer"], priceLevel: 2, latitude: 50.110310, longitude: 8.687467,
            savedFrom: SavedFrom(source: .tiktok, caption: "Craft beer you have to try", savedDaysAgo: 30)),
        Place(
            id: "ima", name: "IMA Multibar", category: .bar, neighbourhood: "Innenstadt",
            address: "Klingerstraße 1", blurb: "Cocktails, food and DJs under one roof.",
            tags: ["Cocktails", "DJ"], priceLevel: 2, latitude: 50.112880, longitude: 8.689078),
        Place(
            id: "fichtekraenzi", name: "Fichtekränzi", category: .food, neighbourhood: "Sachsenhausen",
            address: "Wallstraße 5", blurb: "Tiny Apfelwein pub in the old Sachsenhausen lanes.",
            tags: ["Apfelwein", "Cosy"], priceLevel: 1, latitude: 50.104757, longitude: 8.689153,
            savedFrom: SavedFrom(source: .search, caption: "Saved from search", savedDaysAgo: 40)),
        Place(
            id: "roemer", name: "Römerberg", category: .sight, neighbourhood: "Altstadt",
            address: "Römerberg", blurb: "The old town square with the Römer town hall and half-timbered houses.",
            tags: ["Old town"], priceLevel: nil, latitude: 50.110473, longitude: 8.681563),
        Place(
            id: "eiserner-steg", name: "Eiserner Steg", category: .sight, neighbourhood: "Mainufer",
            address: "Eiserner Steg", blurb: "Iron footbridge with the best skyline view, covered in love locks.",
            tags: ["View", "Sunset"], priceLevel: nil, latitude: 50.108084, longitude: 8.682128),
        Place(
            id: "dom", name: "Kaiserdom", category: .sight, neighbourhood: "Altstadt",
            address: "Domplatz 1", blurb: "Gothic cathedral. Climb the 328 steps of the tower.",
            tags: ["Church", "Tower"], priceLevel: nil, latitude: 50.110667, longitude: 8.685344),
        Place(
            id: "staedel", name: "Städel Museum", category: .sight, neighbourhood: "Museumsufer",
            address: "Schaumainkai 63", blurb: "700 years of art on the museum embankment.",
            tags: ["Art", "Rainy day"], priceLevel: 2, latitude: 50.103219, longitude: 8.673820),
        Place(
            id: "alte-oper", name: "Alte Oper", category: .sight, neighbourhood: "Innenstadt",
            address: "Opernplatz 1", blurb: "Rebuilt opera house, now concerts. The square is great at night.",
            tags: ["Concerts"], priceLevel: nil, latitude: 50.116047, longitude: 8.671987),
        Place(
            id: "goethehaus", name: "Goethe-Haus", category: .sight, neighbourhood: "Altstadt",
            address: "Großer Hirschgraben 23", blurb: "The house where Goethe was born.",
            tags: ["Museum"], priceLevel: 1, latitude: 50.111201, longitude: 8.677593),
        Place(
            id: "palmengarten", name: "Palmengarten", category: .park, neighbourhood: "Westend",
            address: "Siesmayerstraße 61", blurb: "Botanical garden with palm houses and rowing boats on the pond.",
            tags: ["Garden", "Picnic"], priceLevel: 1, latitude: 50.123166, longitude: 8.657729,
            savedFrom: SavedFrom(source: .instagram, caption: "Sunday plan", savedDaysAgo: 12)),
        Place(
            id: "nizza", name: "Nizza Park", category: .park, neighbourhood: "Mainufer",
            address: "Untermainkai", blurb: "Mediterranean riverside garden with palms and fig trees.",
            tags: ["Riverside", "Picnic"], priceLevel: nil, latitude: 50.106520, longitude: 8.673801),
        Place(
            id: "guenthersburgpark", name: "Günthersburgpark", category: .park, neighbourhood: "Nordend",
            address: "Günthersburgallee", blurb: "Neighbourhood park with lawns, playground and a kiosk.",
            tags: ["Lawn", "Kiosk"], priceLevel: nil, latitude: 50.130556, longitude: 8.703421),
    ]

    static func events(now: Date = .now) -> [CityEvent] {
        let cal = Calendar(identifier: .gregorian)
        func at(_ dayOffset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            let day = cal.date(byAdding: .day, value: dayOffset, to: cal.startOfDay(for: now)) ?? now
            return cal.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        }
        return [
            CityEvent(
                id: "sunset-run", title: "Sunset Run along the Main", venue: "Eiserner Steg", kind: "Sport",
                symbol: "figure.run", tint: Palette.orange, start: at(1, 18, 30), durationHours: 1, price: "Free",
                blurb: "Easy 6 km loop over two bridges. All paces welcome.",
                latitude: 50.108084, longitude: 8.682128),
            CityEvent(
                id: "jazz", title: "Late Jam Session", venue: "Jazzkeller", kind: "Music",
                symbol: "music.mic", tint: Palette.purple, start: at(2, 21), durationHours: 3, price: "€8",
                blurb: "Open session in the cellar. Bring an instrument or just listen.",
                latitude: 50.114365, longitude: 8.673736),
            CityEvent(
                id: "market-thu", title: "Farmers' Market", venue: "Konstablerwache", kind: "Food",
                symbol: "basket.fill", tint: Palette.green, start: at(3, 10), durationHours: 10, price: "Free",
                blurb: "Regional produce, Handkäs and Apfelwein stands in the middle of the city.",
                latitude: 50.114630, longitude: 8.686825),
            CityEvent(
                id: "mousonturm", title: "Dance Night", venue: "Mousonturm", kind: "Stage",
                symbol: "theatermasks.fill", tint: Palette.pink, start: at(4, 20), durationHours: 2, price: "€18",
                blurb: "Contemporary dance double bill.",
                latitude: 50.119149, longitude: 8.698816),
            CityEvent(
                id: "flohmarkt", title: "Riverside Flea Market", venue: "Museumsufer", kind: "Market",
                symbol: "tag.fill", tint: Palette.blue, start: at(5, 9), durationHours: 5, price: "Free",
                blurb: "Vinyl, vintage and old cameras along the Schaumainkai.",
                latitude: 50.105064, longitude: 8.677686),
            CityEvent(
                id: "ebbelwei", title: "Ebbelwei-Express Ride", venue: "Zoo stop", kind: "Tour",
                symbol: "tram.fill", tint: Palette.indigo, start: at(6, 13, 30), durationHours: 1, price: "€10",
                blurb: "The old tram loops the city with Apfelwein and pretzels on board.",
                latitude: 50.115642, longitude: 8.701960),
        ]
    }
}
