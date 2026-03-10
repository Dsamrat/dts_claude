import 'package:shared_preferences/shared_preferences.dart';

class UserPreferences {
  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('userId');
  }

  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userName');
  }

  static Future<int?> getBranchId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('branchId');
  }

  static Future<int?> userIsPickupTeam() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('isPickupTeam');
  }

  static Future<int?> userHasMultiBranchAccess() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('multiBranch');
  }

  static Future<Map<String, dynamic>> getUserDetails() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'userId': prefs.getInt('userId'),
      'userName': prefs.getString('userName'),
      'branchId': prefs.getInt('branchId'),
      'isPickupTeam': prefs.getInt('isPickupTeam'),
      'multiBranch': prefs.getInt('multiBranch'),
      'viewOnly': prefs.getInt('viewOnly'),
    };
  }
}
