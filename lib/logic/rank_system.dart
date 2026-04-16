/// Rank system mapping ELO scores to rank levels and badges.
class RankSystem {
  /// Định nghĩa các rank levels và điểm ELO tương ứng.
  static const List<int> eloThresholds = [
    0, // Rank 1: 0–799
    800, // Rank 2: 800–1099
    1100, // Rank 3: 1100–1399
    1400, // Rank 4: 1400–1649
    1650, // Rank 5: 1650+
  ];

  static const Map<int, String> rankNames = {
    1: 'Tập sự',
    2: 'Trung cấp',
    3: 'Cao cấp',
    4: 'Chuyên gia',
    5: 'Đại kiện tướng',
  };

  static const Map<int, String> rankEnglish = {
    1: 'Novice',
    2: 'Intermediate',
    3: 'Advanced',
    4: 'Expert',
    5: 'Master',
  };

  static const Map<int, String> rankBadgeAssetNames = {
    1: 'bronze',
    2: 'silver',
    3: 'gold',
    4: 'diamond',
    5: 'king',
  };

  /// Xác định rank dựa vào ELO score.
  static int getRankFromElo(int elo) {
    if (elo >= 1650) return 5;
    if (elo >= 1400) return 4;
    if (elo >= 1100) return 3;
    if (elo >= 800) return 2;
    return 1;
  }

  /// Lấy tên rank (Tiếng Việt).
  static String getRankName(int elo) {
    final rank = getRankFromElo(elo);
    return rankNames[rank] ?? 'Unknown';
  }

  /// Lấy tên rank (Tiếng Anh).
  static String getRankNameEnglish(int elo) {
    final rank = getRankFromElo(elo);
    return rankEnglish[rank] ?? 'Unknown';
  }

  /// Lấy badge asset path cho rank (dùng cho UI).
  static String getRankBadgePath(int elo) {
    final rank = getRankFromElo(elo);
    final badge = rankBadgeAssetNames[rank] ?? 'bronze';
    return 'assets/images/rank/$badge.png';
  }

  /// Kiểm tra xem ELO có hợp lệ để hiển thị rank không.
  static bool isValidElo(int elo) => elo >= 0;
}
