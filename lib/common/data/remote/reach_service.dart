// lib/common/data/remote/reach_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ReachService {
  Future<dynamic> fetchReach(String reachId) async {
    final response = await http.get(
      Uri.parse('https://api.water.noaa.gov/nwps/v1/reaches/$reachId'),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load reach data');
    }
  }
}
