class SalesPerson {
  final int? id;
  final String name;
  final String? contactNum;

  //Creating constructor
  SalesPerson({this.id, required this.name, this.contactNum});
  //Create Branch from JSON
  factory SalesPerson.fromJson(Map<String, dynamic> json) {
    return SalesPerson(
      id: json['id'],
      name: json['name'],
      contactNum: json['contactNum'],
    );
  }
  //post / put as json
  Map<String, dynamic> toJson() {
    return {'name': name};
  }
}
