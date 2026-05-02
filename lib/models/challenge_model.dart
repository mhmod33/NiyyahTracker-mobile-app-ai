class Challenge {
  final String id;
  final String title;
  final String desc;
  final String icon; // Icon name as string
  final int target;
  final int current;
  final List<String> gradient; // Hex colors

  Challenge({
    required this.id,
    required this.title,
    required this.desc,
    required this.icon,
    required this.target,
    this.current = 0,
    required this.gradient,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'desc': desc,
      'icon': icon,
      'target': target,
      'current': current,
      'gradient': gradient,
    };
  }

  factory Challenge.fromMap(Map<String, dynamic> map) {
    return Challenge(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      desc: map['desc'] ?? '',
      icon: map['icon'] ?? 'star',
      target: map['target'] ?? 30,
      current: map['current'] ?? 0,
      gradient: List<String>.from(map['gradient'] ?? []),
    );
  }

  Challenge copyWith({int? current}) {
    return Challenge(
      id: id,
      title: title,
      desc: desc,
      icon: icon,
      target: target,
      current: current ?? this.current,
      gradient: gradient,
    );
  }
}
