class Branch {
  final int? id;
  final String name;
  final int? status;
  final String? updatedAt;

  //Creating constructor
  Branch({this.id, required this.name, this.status, this.updatedAt});
  //Create Branch from JSON
  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: json['bm_id'],
      name: json['bm_name'],
      status: json['bm_status'],
      updatedAt: json['bm_update_at'],
    );
  }
  //post / put as json
  Map<String, dynamic> toJson() {
    return {'name': name};
  }
}
