class CommercialVisit {
  final int? id;
  final int userId;
  final String clientName;
  final String location;
  final String cleaningType;
  final String visitDate;
  final String contact;
  final String relanceDate;

  CommercialVisit({
    this.id,
    required this.userId,
    required this.clientName,
    required this.location,
    required this.cleaningType,
    required this.visitDate,
    required this.contact,
    required this.relanceDate,
  });

  factory CommercialVisit.fromJson(Map<String, dynamic> json) {
    return CommercialVisit(
      id: json['id'],
      userId: json['user_id'],
      clientName: json['client_name'],
      location: json['location'],
      cleaningType: json['cleaning_type'],
      visitDate: json['visit_date'],
      contact: json['contact'],
      relanceDate: json['relance_date'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'client_name': clientName,
      'location': location,
      'cleaning_type': cleaningType,
      'visit_date': visitDate,
      'contact': contact,
      'relance_date': relanceDate,
    };
  }
}
