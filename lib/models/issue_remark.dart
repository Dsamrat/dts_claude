class IssueRemark {
  final int id;
  final String remarks;
  final int affectFlag;

  IssueRemark({
    required this.id,
    required this.remarks,
    required this.affectFlag,
  });

  factory IssueRemark.fromJson(Map<String, dynamic> json) {
    return IssueRemark(
      id: json['id'],
      remarks: json['remarks'],
      affectFlag: json['affect_flag'],
    );
  }
}
