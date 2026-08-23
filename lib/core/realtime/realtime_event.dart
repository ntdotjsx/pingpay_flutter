class RealtimeEvent {
  final String type;
  final String eventId;
  final DateTime timestamp;
  final String? resourceId;
  final int? version;
  final Map<String, dynamic> data;

  const RealtimeEvent({
    required this.type,
    required this.eventId,
    required this.timestamp,
    this.resourceId,
    this.version,
    required this.data,
  });

  factory RealtimeEvent.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    return RealtimeEvent(
      type: json['type']?.toString() ?? '',
      eventId: json['eventId']?.toString() ?? '',
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.now(),
      resourceId: json['resourceId']?.toString(),
      version: json['version'] is int ? json['version'] as int : null,
      data: data is Map ? Map<String, dynamic>.from(data) : const {},
    );
  }
}

class RealtimeEventDeduper {
  final int maxEntries;
  final List<String> _orderedIds = [];
  final Set<String> _seenIds = {};

  RealtimeEventDeduper({this.maxEntries = 300});

  bool shouldProcess(RealtimeEvent event) {
    if (event.eventId.isEmpty) return true;
    if (_seenIds.contains(event.eventId)) return false;

    _seenIds.add(event.eventId);
    _orderedIds.add(event.eventId);

    while (_orderedIds.length > maxEntries) {
      final removed = _orderedIds.removeAt(0);
      _seenIds.remove(removed);
    }

    return true;
  }

  void clear() {
    _orderedIds.clear();
    _seenIds.clear();
  }
}
