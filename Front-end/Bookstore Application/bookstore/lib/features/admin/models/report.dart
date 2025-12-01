class Report {
  final String id;
  final String title;
  final DateTime date;
  final Map<String, dynamic> data;

  Report({
    required this.id,
    required this.title,
    required this.date,
    required this.data,
  });
}
