// User public-profile layer: the current user's @username + linked social
// accounts, plus a local cache of known profiles (keyed by username) so a
// recipe's "Hazırlayan" name can resolve to a public profile.
//
// Like the rest of the app this is stored LOCALLY for now and persisted by
// StorageService. When Firebase is added these map to /users/{uid} public
// profile docs; the UI stays the same.

import 'food_database.dart';

/// Social platforms a user can link, in display order.
const List<String> kSocialPlatforms = [
  "instagram",
  "tiktok",
  "youtube",
  "facebook",
  "x",
  "whatsapp",
];

/// Human label for each platform.
const Map<String, String> kSocialLabels = {
  "instagram": "Instagram",
  "tiktok": "TikTok",
  "youtube": "YouTube",
  "facebook": "Facebook",
  "x": "X",
  "whatsapp": "WhatsApp",
};

class UserProfile {
  String username; // shown as @username and stored as Recipe.author
  Map<String, String> socials; // platform -> handle/url (empty = not linked)

  UserProfile({this.username = "", Map<String, String>? socials})
      : socials = socials ?? {};

  Map<String, dynamic> toJson() => {
        "username": username,
        "socials": socials,
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        username: j["username"]?.toString() ?? "",
        socials: (j["socials"] as Map?)
                ?.map((k, v) => MapEntry(k.toString(), v.toString())) ??
            {},
      );

  UserProfile copy() => UserProfile(username: username, socials: Map.from(socials));
}

/// The current user's profile (null until they set one).
UserProfile? globalMyProfile;

/// username -> profile json. Locally this holds at least the current user's
/// profile; with Firebase it fills from other users' public profiles.
final Map<String, Map<String, dynamic>> globalKnownProfiles = {};

/// Mevcut kullanıcının takip ettiği @kullanıcı adları (küçük harf).
final Set<String> globalMyFollowing = {};

/// Bu kullanıcıyı takip ediyor muyum?
bool isFollowing(String username) =>
    globalMyFollowing.contains(username.trim().toLowerCase());

/// Engellenen @kullanıcı adları (küçük harf). İçerikleri (topluluk/yorum)
/// yerel olarak gizlenir.
final Set<String> globalBlockedUsers = {};

bool isBlockedUser(String username) =>
    globalBlockedUsers.contains(username.trim().toLowerCase());

/// Talep edilebilecek uzman türleri.
const List<String> kExpertTypes = [
  "Doktor",
  "Çocuk Doktoru",
  "Hemşire",
  "Ebe",
  "Diyetisyen",
  "Çocuk Gelişimi Uzmanı",
  "Psikolog",
];

/// Admin onaylı uzmanlar: username (küçük harf) -> uzman türü.
/// SocialSync.loadExperts() ile Firestore /experts'ten doldurulur.
final Map<String, String> globalExperts = {};

/// Bir yazarın (username) onaylı uzman türü; uzman değilse null.
String? expertTypeForAuthor(String author) {
  final a = author.trim().toLowerCase();
  if (a.isEmpty) return null;
  return globalExperts[a];
}

/// The current user's @username. Falls back to a slug of [fallbackName] (e.g.
/// the parent name) when no profile/username has been set yet.
String myUsername({String fallbackName = ""}) {
  final u = globalMyProfile?.username.trim() ?? "";
  if (u.isNotEmpty) return u;
  return usernameSlug(fallbackName);
}

/// Turns a display name into a safe @handle slug ("Ayşe Yılmaz" -> "ayse_yilmaz").
String usernameSlug(String name) {
  var s = name.trim().toLowerCase();
  if (s.isEmpty) return "kullanici";
  const tr = {"ç": "c", "ğ": "g", "ı": "i", "ö": "o", "ş": "s", "ü": "u", "â": "a", "î": "i", "û": "u"};
  tr.forEach((k, v) => s = s.replaceAll(k, v));
  s = s.replaceAll(RegExp(r"[^a-z0-9]+"), "_").replaceAll(RegExp(r"^_+|_+$"), "");
  return s.isEmpty ? "kullanici" : s;
}

/// Resolves a recipe's author name to a known public profile, or null.
UserProfile? profileForAuthor(String author) {
  final a = author.trim();
  if (a.isEmpty) return null;
  // Current user's own profile.
  if (globalMyProfile != null && globalMyProfile!.username.trim() == a) {
    return globalMyProfile;
  }
  final j = globalKnownProfiles[a];
  return j == null ? null : UserProfile.fromJson(j);
}

/// All published recipes authored by [username] (pending ones are excluded —
/// they aren't in globalRecipesDatabase yet).
List<Recipe> recipesByAuthor(String username) {
  final u = username.trim();
  if (u.isEmpty) return const [];
  return globalRecipesDatabase.where((r) => r.author.trim() == u).toList();
}

/// Builds an openable URL for a linked social account. Accepts either a full
/// URL or a bare handle (with/without a leading @).
String socialUrl(String platform, String value) {
  var v = value.trim();
  if (v.isEmpty) return "";
  if (v.startsWith("http://") || v.startsWith("https://")) return v;
  final handle = v.replaceAll("@", "").trim();
  switch (platform) {
    case "instagram":
      return "https://instagram.com/$handle";
    case "tiktok":
      return "https://tiktok.com/@$handle";
    case "youtube":
      return "https://youtube.com/@$handle";
    case "facebook":
      return "https://facebook.com/$handle";
    case "x":
      return "https://x.com/$handle";
    case "whatsapp":
      // Strip non-digits for a wa.me link.
      final digits = v.replaceAll(RegExp(r"[^0-9]"), "");
      return digits.isEmpty ? "" : "https://wa.me/$digits";
    default:
      return v;
  }
}
