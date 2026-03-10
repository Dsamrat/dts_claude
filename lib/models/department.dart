class Department {
  final int? id;
  final String name;

  Department({this.id, required this.name});

  // Factory constructor to create a Branch from JSON response
  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(id: json['dep_id'], name: json['dep_name']);
  }

  // Convert Branch instance to JSON format for POST/PUT requests
  Map<String, dynamic> toJson() {
    return {
      'name': name, // In your case, we only need the name for POST/PUT
    };
  }
}
