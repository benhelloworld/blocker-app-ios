import Foundation

/// Curated mapping of popular apps (bundle IDs / display names) and Screen Time
/// category names to website domains. Used to automatically block the website of
/// every app the user blocks, without manual steps.
enum AppDomainCatalog {

    // MARK: - Model

    enum DomainGroup: String, CaseIterable {
        case social, video, messaging, news, shopping, games, entertainment

        var domains: [String] {
            switch self {
            case .social:
                return [
                    "facebook.com", "www.facebook.com",
                    "instagram.com", "www.instagram.com",
                    "tiktok.com", "www.tiktok.com",
                    "x.com", "twitter.com", "www.twitter.com",
                    "reddit.com", "www.reddit.com",
                    "snapchat.com", "www.snapchat.com",
                    "pinterest.com", "www.pinterest.com",
                    "linkedin.com", "www.linkedin.com",
                    "threads.net", "www.threads.net",
                    "bereal.com", "www.bereal.com"
                ]
            case .video:
                return [
                    "youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be",
                    "netflix.com", "www.netflix.com",
                    "twitch.tv", "www.twitch.tv",
                    "disneyplus.com", "www.disneyplus.com",
                    "primevideo.com", "www.primevideo.com"
                ]
            case .messaging:
                return [
                    "whatsapp.com", "www.whatsapp.com", "web.whatsapp.com",
                    "messenger.com", "www.messenger.com",
                    "telegram.org", "web.telegram.org",
                    "discord.com", "www.discord.com"
                ]
            case .news:
                return [
                    "bbc.com", "www.bbc.com", "bbc.co.uk", "www.bbc.co.uk",
                    "cnn.com", "www.cnn.com",
                    "nytimes.com", "www.nytimes.com",
                    "theguardian.com", "www.theguardian.com"
                ]
            case .shopping:
                return [
                    "amazon.com", "www.amazon.com",
                    "ebay.com", "www.ebay.com",
                    "zalando.ch", "www.zalando.ch", "zalando.de", "www.zalando.de"
                ]
            case .games:
                return [
                    "king.com", "www.king.com",
                    "supercell.com", "www.supercell.com"
                ]
            case .entertainment:
                return [
                    "spotify.com", "www.spotify.com", "open.spotify.com"
                ]
            }
        }
    }

    struct AppEntry {
        let bundleIDs: Set<String>
        let displayNames: Set<String>
        let domains: [String]
        let group: DomainGroup
    }

    // MARK: - Catalog

    static let apps: [AppEntry] = [
        AppEntry(bundleIDs: ["com.burbn.instagram"], displayNames: ["instagram", "instagram app"],
                 domains: ["instagram.com", "www.instagram.com"], group: .social),
        AppEntry(bundleIDs: ["com.google.ios.youtube"], displayNames: ["youtube", "youtube app"],
                 domains: ["youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be"], group: .video),
        AppEntry(bundleIDs: ["com.zhiliaoapp.musically"], displayNames: ["tiktok", "tiktok app"],
                 domains: ["tiktok.com", "www.tiktok.com"], group: .social),
        AppEntry(bundleIDs: ["com.facebook.Facebook"], displayNames: ["facebook", "facebook app"],
                 domains: ["facebook.com", "www.facebook.com"], group: .social),
        AppEntry(bundleIDs: ["com.atebits.Tweetie2", "com.twitter.x"], displayNames: ["x", "twitter", "x app", "twitter app"],
                 domains: ["x.com", "twitter.com", "www.twitter.com"], group: .social),
        AppEntry(bundleIDs: ["com.reddit.Reddit"], displayNames: ["reddit", "reddit app"],
                 domains: ["reddit.com", "www.reddit.com"], group: .social),
        AppEntry(bundleIDs: ["com.toyopagroup.picaboo"], displayNames: ["snapchat", "snapchat app"],
                 domains: ["snapchat.com", "www.snapchat.com"], group: .social),
        AppEntry(bundleIDs: ["net.whatsapp.WhatsApp"], displayNames: ["whatsapp", "whatsapp app"],
                 domains: ["whatsapp.com", "www.whatsapp.com", "web.whatsapp.com"], group: .messaging),
        AppEntry(bundleIDs: ["com.facebook.Messenger"], displayNames: ["messenger", "messenger app"],
                 domains: ["messenger.com", "www.messenger.com"], group: .messaging),
        AppEntry(bundleIDs: ["com.pinterest.Pinterest"], displayNames: ["pinterest", "pinterest app"],
                 domains: ["pinterest.com", "www.pinterest.com"], group: .social),
        AppEntry(bundleIDs: ["com.linkedin.LinkedIn"], displayNames: ["linkedin", "linkedin app"],
                 domains: ["linkedin.com", "www.linkedin.com"], group: .social),
        AppEntry(bundleIDs: ["com.netflix.Netflix"], displayNames: ["netflix", "netflix app"],
                 domains: ["netflix.com", "www.netflix.com"], group: .video),
        AppEntry(bundleIDs: ["tv.twitch"], displayNames: ["twitch", "twitch app"],
                 domains: ["twitch.tv", "www.twitch.tv"], group: .video),
        AppEntry(bundleIDs: ["com.hammerandchisel.discord"], displayNames: ["discord", "discord app"],
                 domains: ["discord.com", "www.discord.com"], group: .messaging),
        AppEntry(bundleIDs: ["ph.telegra.Telegraph"], displayNames: ["telegram", "telegram app"],
                 domains: ["telegram.org", "web.telegram.org"], group: .messaging),
        AppEntry(bundleIDs: ["com.bereal.BeReal"], displayNames: ["bereal", "be real"],
                 domains: ["bereal.com", "www.bereal.com"], group: .social),
        AppEntry(bundleIDs: ["com.burbn.threads"], displayNames: ["threads", "threads app"],
                 domains: ["threads.net", "www.threads.net"], group: .social),
        AppEntry(bundleIDs: ["com.spotify.client"], displayNames: ["spotify", "spotify app"],
                 domains: ["spotify.com", "www.spotify.com", "open.spotify.com"], group: .entertainment),
        AppEntry(bundleIDs: ["com.amazon.Amazon"], displayNames: ["amazon", "amazon shopping"],
                 domains: ["amazon.com", "www.amazon.com"], group: .shopping),
        AppEntry(bundleIDs: ["com.ebay.app"], displayNames: ["ebay", "ebay app"],
                 domains: ["ebay.com", "www.ebay.com"], group: .shopping)
    ]

    /// Screen Time category display names (localized) -> domain groups.
    /// The report extension reports category names via `localizedDisplayName`;
    /// we match them case-insensitively against these known keys.
    static let categoryGroups: [(keys: Set<String>, group: DomainGroup)] = [
        (["social networking", "soziale netzwerke", "redes sociales", "social", "sozial"], .social),
        (["video", "videos", "entertainment", "unterhaltung"], .video),
        (["messaging", "nachrichten", "mensajería"], .messaging),
        (["news", "nachrichten", "noticias"], .news),
        (["shopping", "einkaufen", "compras"], .shopping),
        (["games", "spiele", "juegos"], .games)
    ]

    /// URL scheme per bundle ID, used to reopen a delay-app directly after the
    /// anti-impulse pause ("Open it" jumps straight into the app).
    static let urlSchemes: [String: String] = [
        "com.burbn.instagram": "instagram://",
        "com.google.ios.youtube": "youtube://",
        "com.zhiliaoapp.musically": "tiktok://",
        "com.facebook.Facebook": "fb://",
        "com.atebits.Tweetie2": "x://",
        "com.twitter.x": "x://",
        "com.reddit.Reddit": "reddit://",
        "com.toyopagroup.picaboo": "snapchat://",
        "net.whatsapp.WhatsApp": "whatsapp://",
        "com.facebook.Messenger": "fb-messenger://",
        "com.pinterest.Pinterest": "pinterest://",
        "com.linkedin.LinkedIn": "linkedin://",
        "com.netflix.Netflix": "nflx://",
        "tv.twitch": "twitch://",
        "com.hammerandchisel.discord": "discord://",
        "ph.telegra.Telegraph": "tg://",
        "com.bereal.BeReal": "bereal://",
        "com.burbn.threads": "threads://",
        "com.spotify.client": "spotify://",
        "com.amazon.Amazon": "amzn://",
        "com.ebay.app": "ebay://"
    ]

    static func urlScheme(forBundleID bundleID: String) -> String? {
        let lower = bundleID.lowercased()
        for (key, scheme) in urlSchemes where key.lowercased() == lower {
            return scheme
        }
        return nil
    }

    // MARK: - Lookup

    /// Domains for a set of bundle IDs (e.g. selected in the report picker).
    static func domains(forBundleIDs bundleIDs: Set<String>) -> [String] {
        let lower = bundleIDs.map { $0.lowercased() }
        return apps
            .filter { entry in entry.bundleIDs.contains { lower.contains($0.lowercased()) } }
            .flatMap(\.domains)
    }

    /// Domains for a set of app display names (case-insensitive).
    static func domains(forDisplayNames names: Set<String>) -> [String] {
        let lower = names.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        return apps
            .filter { entry in entry.displayNames.contains { lower.contains($0.lowercased()) } }
            .flatMap(\.domains)
    }

    /// Domains for a set of Screen Time category display names.
    static func domains(forCategoryNames categoryNames: Set<String>) -> [String] {
        let lower = categoryNames.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        var result: [String] = []
        for (keys, group) in categoryGroups where !keys.isDisjoint(with: lower) {
            result.append(contentsOf: group.domains)
        }
        return result
    }

    /// Full domain group for a category key.
    static func domains(forGroup group: DomainGroup) -> [String] {
        group.domains
    }

    /// Deduplicated, sanitized merge.
    static func mergedDomains(_ sets: [String]...) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for set in sets {
            for domain in set {
                let cleaned = MacBlockDomainPreset.sanitized([domain]).first ?? domain.lowercased()
                guard !cleaned.isEmpty, !seen.contains(cleaned) else { continue }
                seen.insert(cleaned)
                out.append(cleaned)
            }
        }
        return out.sorted()
    }
}
