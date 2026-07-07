class Committee {
  Committee({required this.id, required this.nameAr, required this.nameEn});

  final int id;
  final String nameAr;
  final String nameEn;

  factory Committee.fromMap(Map<String, dynamic> m) => Committee(
        id: m['id'] as int,
        nameAr: m['name_ar'] as String,
        nameEn: m['name_en'] as String,
      );
}

class CommitteeMembership {
  CommitteeMembership({
    required this.committeeId,
    required this.committeeNameAr,
    required this.committeeNameEn,
    required this.role,
  });

  final int committeeId;
  final String committeeNameAr;
  final String committeeNameEn;
  final String role; // head | vice_head | member
}
