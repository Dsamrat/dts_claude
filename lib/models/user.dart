class User {
  final int? id;
  final String name;
  final String contact;
  final String userName;
  final String password;
  final int departmentId;
  final int branchId;
  final bool? multiBranch;
  final String? createdAt;
  final String? updatedAt;

  User({
    this.id,
    required this.name,
    required this.contact,
    required this.userName,
    required this.password,
    required this.departmentId,
    required this.branchId,
    this.multiBranch,
    this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      contact: json['contactNum'],
      userName: json['userName'],
      password: "", // password usually not sent back in response
      departmentId: json['departmentId'],
      branchId: json['branchId'],
      multiBranch: json['multiBranch'] == 1, // convert int to bool
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'contact': contact,
      'userName': userName,
      'password': password,
      'department_id': departmentId,
      'branch_id': branchId,
      'multiBranch':
          multiBranch == true ? 1 : 0, // convert bool to int for backend
    };
  }

  @override
  String toString() {
    return 'User(name: $name, contact: $contact, userName: $userName, departmentId: $departmentId, branchId: $branchId, multiBranch: $multiBranch)';
  }
}
