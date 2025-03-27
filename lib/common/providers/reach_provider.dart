// lib/common/providers/reach_provider.dart
import 'package:flutter/material.dart';
import 'package:rivr/common/data/remote/reach_service.dart';

class ReachProvider with ChangeNotifier {
  final Map<String, dynamic> _reaches = {};

  dynamic getReach(String reachId) => _reaches[reachId];

  Future<void> fetchReach(String reachId) async {
    if (_reaches.containsKey(reachId)) {
      print('Reach for $reachId already fetched');
      // Already fetched
      return;
    }

    try {
      final reachService = ReachService();
      final reachData = await reachService.fetchReach(reachId);
      _reaches[reachId] = reachData;
    } catch (e) {
      _reaches[reachId] = null; // Handle error state
      print('Error fetching reach: $e');
    }
    notifyListeners();
  }
}
