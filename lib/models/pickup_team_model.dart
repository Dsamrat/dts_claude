class PickupTeamModel {
  final int pkId;
  final int pkBranch;
  final String pkName;

  PickupTeamModel({
    required this.pkId,
    required this.pkBranch,
    required this.pkName,
  });

  factory PickupTeamModel.fromJson(Map<String, dynamic> json) {
    return PickupTeamModel(
      pkId: int.parse(json['pk_id'].toString()),
      pkBranch: int.parse(json['pk_branch'].toString()),
      pkName: json['pk_name'] ?? '',
    );
  }
}
