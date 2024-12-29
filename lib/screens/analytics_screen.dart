import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class DentalAnalyticsScreen extends StatefulWidget {
  const DentalAnalyticsScreen({super.key});

  @override
  State<DentalAnalyticsScreen> createState() => _DentalAnalyticsScreenState();
}

class _DentalAnalyticsScreenState extends State<DentalAnalyticsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<Map<String, List<Map<String, dynamic>>>> _fetchUserData() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return {};

    // Fetch gingivitis data
    final gingivitisSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('gingivitis_detection')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .get();

    // Fetch calculus data
    final calculusSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('plaque_detection')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .get();

    return {
      'gingivitis': gingivitisSnapshot.docs
          .map((doc) => {
                ...doc.data(),
                'id': doc.id,
                'timestamp': (doc.data()['timestamp'] as Timestamp).toDate(),
              })
          .toList(),
      'calculus': calculusSnapshot.docs
          .map((doc) => {
                ...doc.data(),
                'id': doc.id,
                'timestamp': (doc.data()['timestamp'] as Timestamp).toDate(),
              })
          .toList(),
    };
  }

  Widget _buildGingivitisOverview(List<Map<String, dynamic>> data) {
    if (data.isEmpty) {
      return _buildEmptyState('No gingivitis detection history available');
    }

    final latestScan = data.first;
    final hasGingivitis = latestScan['hasGingivitis'] ?? false;
    final maxSeverity = latestScan['maxSeverity'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gingivitis Status',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: hasGingivitis ? Colors.red[100] : Colors.green[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    hasGingivitis ? Icons.warning : Icons.check_circle,
                    color: hasGingivitis ? Colors.red : Colors.green,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasGingivitis ? 'Signs of Gingivitis' : 'Healthy Gums',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: hasGingivitis
                                      ? Colors.red
                                      : Colors.green[700],
                                ),
                      ),
                      if (hasGingivitis && maxSeverity != null)
                        Text(
                          'Maximum Severity: ${_getSeverityText(maxSeverity)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      Text(
                        'Last Scan: ${DateFormat('MMM d, y').format(latestScan['timestamp'])}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalculusOverview(List<Map<String, dynamic>> data) {
    if (data.isEmpty) {
      return _buildEmptyState('No calculus detection history available');
    }

    final latestScan = data.first;
    final prediction = latestScan['topPrediction'] ?? '';
    final hasCalculus = prediction.toLowerCase().contains('heavy') ||
        prediction.toLowerCase().contains('light');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Calculus Status',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: hasCalculus ? Colors.orange[100] : Colors.green[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    hasCalculus ? Icons.warning : Icons.check_circle,
                    color: hasCalculus ? Colors.orange : Colors.green,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prediction.toUpperCase(),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: hasCalculus
                                      ? Colors.orange[700]
                                      : Colors.green[700],
                                ),
                      ),
                      Text(
                        'Confidence: ${(latestScan['confidence'] * 100).toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        'Last Scan: ${DateFormat('MMM d, y').format(latestScan['timestamp'] ?? DateTime.now())}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

// Replace the _buildTrendsGraph method with this new analytical summary widget
  Widget _buildStatusSummary(List<Map<String, dynamic>> gingivitisData,
      List<Map<String, dynamic>> calculusData) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Status Summary',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            // Overall Health Status
            _buildOverallStatus(gingivitisData, calculusData),
            const Divider(height: 32),
            // Last Check Stats
            _buildLastCheckStats(gingivitisData, calculusData),
            const Divider(height: 32),
            // Improvement Tracking
            _buildImprovementTracking(gingivitisData, calculusData),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallStatus(List<Map<String, dynamic>> gingivitisData,
      List<Map<String, dynamic>> calculusData) {
    final hasGingivitis =
        gingivitisData.isNotEmpty && gingivitisData.first['hasGingivitis'];
    final hasCalculus = calculusData.isNotEmpty &&
        calculusData.first['topPrediction']
            .toString()
            .toLowerCase()
            .contains('calculus');

    final overallStatus = !hasGingivitis && !hasCalculus
        ? 'Healthy'
        : (hasGingivitis && hasCalculus)
            ? 'Needs Attention'
            : 'Monitor';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: overallStatus == 'Healthy'
            ? Colors.green.withOpacity(0.1)
            : overallStatus == 'Monitor'
                ? Colors.orange.withOpacity(0.1)
                : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            overallStatus == 'Healthy'
                ? Icons.check_circle
                : overallStatus == 'Monitor'
                    ? Icons.warning
                    : Icons.error,
            color: overallStatus == 'Healthy'
                ? Colors.green
                : overallStatus == 'Monitor'
                    ? Colors.orange
                    : Colors.red,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overall Dental Health',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  overallStatus,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: overallStatus == 'Healthy'
                        ? Colors.green
                        : overallStatus == 'Monitor'
                            ? Colors.orange
                            : Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastCheckStats(List<Map<String, dynamic>> gingivitisData,
      List<Map<String, dynamic>> calculusData) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Last Check Statistics',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (gingivitisData.isNotEmpty)
          _buildStatItem(
            'Gingivitis Severity',
            gingivitisData.first['hasGingivitis']
                ? _getSeverityText(gingivitisData.first['maxSeverity'])
                : 'None',
            Icons.medical_information,
          ),
        if (calculusData.isNotEmpty)
          _buildStatItem(
            'Calculus Status',
            calculusData.first['topPrediction'].toString(),
            Icons.analytics,
          ),
      ],
    );
  }

  Widget _buildImprovementTracking(List<Map<String, dynamic>> gingivitisData,
      List<Map<String, dynamic>> calculusData) {
    // Calculate improvements
    String gingivitisProgress =
        _calculateProgress(gingivitisData, 'gingivitis');
    String calculusProgress = _calculateProgress(calculusData, 'calculus');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Progress Tracking',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        _buildProgressItem('Gingivitis', gingivitisProgress),
        const SizedBox(height: 8),
        _buildProgressItem('Calculus', calculusProgress),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressItem(String condition, String progress) {
    IconData icon;
    Color color;

    switch (progress) {
      case 'Improving':
        icon = Icons.trending_up;
        color = Colors.green;
        break;
      case 'Worsening':
        icon = Icons.trending_down;
        color = Colors.red;
        break;
      default:
        icon = Icons.trending_flat;
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(condition, style: Theme.of(context).textTheme.bodyMedium),
                Text(
                  progress,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _calculateProgress(List<Map<String, dynamic>> data, String type) {
    if (data.length < 2) return 'Not Enough Data';

    if (type == 'gingivitis') {
      bool currentHasCondition = data[0]['hasGingivitis'];
      bool previousHasCondition = data[1]['hasGingivitis'];
      int currentSeverity = data[0]['maxSeverity'] ?? 0;
      int previousSeverity = data[1]['maxSeverity'] ?? 0;

      if (!currentHasCondition && previousHasCondition) return 'Improving';
      if (currentHasCondition && !previousHasCondition) return 'Worsening';
      if (currentHasCondition && previousHasCondition) {
        if (currentSeverity < previousSeverity) return 'Improving';
        if (currentSeverity > previousSeverity) return 'Worsening';
      }
    } else {
      bool currentHasLightCalculus =
          data[0]['topPrediction'].toString().toLowerCase().contains('light');
      bool currentHasheavyCalculus =
          data[0]['topPrediction'].toString().toLowerCase().contains('heavy');
      bool currentHasNoCalculus =
          data[0]['topPrediction'].toString().toLowerCase().contains('free');
      bool previousHasLightCalculus =
          data[1]['topPrediction'].toString().toLowerCase().contains('light');
      bool previousHasheavyCalculus =
          data[1]['topPrediction'].toString().toLowerCase().contains('heavy');
      bool previousHasNoCalculus =
          data[1]['topPrediction'].toString().toLowerCase().contains('free');

      if ((currentHasNoCalculus &&
              (previousHasLightCalculus || previousHasheavyCalculus)) ||
          (currentHasLightCalculus && previousHasheavyCalculus))
        return 'Improving';
      if (currentHasheavyCalculus &&
              (previousHasLightCalculus || previousHasNoCalculus) ||
          (currentHasLightCalculus && previousHasNoCalculus))
        return 'Worsening';
    }

    return 'Stable';
  }

  Widget _buildRecommendations(Map<String, List<Map<String, dynamic>>> data) {
    final gingivitisData = data['gingivitis'] ?? [];
    final calculusData = data['calculus'] ?? [];

    // Return early with a default message if no data is available
    if (gingivitisData.isEmpty && calculusData.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recommendations',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _buildRecommendationItem(
                'Start tracking your dental health',
                'Take regular scans to receive personalized recommendations.',
                Icons.track_changes,
              ),
            ],
          ),
        ),
      );
    }

    final hasGingivitis = gingivitisData.isNotEmpty &&
        (gingivitisData.first['hasGingivitis'] ?? false);
    final calculusPrediction = calculusData.isNotEmpty
        ? calculusData.first['topPrediction']?.toString().toLowerCase() ?? ''
        : '';
    final hasCalculus = calculusPrediction.contains('heavy') ||
        calculusPrediction.contains('light');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recommendations',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (hasGingivitis) ...[
              _buildRecommendationItem(
                'Schedule a dental check-up',
                'Your gums show signs of gingivitis. Professional cleaning and examination is recommended.',
                Icons.calendar_today,
              ),
              _buildRecommendationItem(
                'Improve brushing technique',
                'Focus on gentle circular motions along the gum line.',
                Icons.brush,
              ),
            ],
            if (hasCalculus) ...[
              _buildRecommendationItem(
                'Professional cleaning needed',
                'Calculus buildup requires professional removal.',
                Icons.cleaning_services,
              ),
            ],
            if (!hasGingivitis &&
                !hasCalculus &&
                (gingivitisData.isNotEmpty || calculusData.isNotEmpty))
              _buildRecommendationItem(
                'Maintain good habits',
                'Continue your current oral hygiene routine.',
                Icons.check_circle,
              ),
            _buildRecommendationItem(
              'Regular monitoring',
              'Take scans every 2-3 weeks to track your progress.',
              Icons.track_changes,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationItem(
      String title, String description, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.blue[700]),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.no_photography,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  String _getSeverityText(int severity) {
    switch (severity) {
      case 3:
        return 'Mild';
      case 4:
        return 'Moderate';
      case 5:
        return 'Severe';
      case 6:
        return 'Very Severe';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dental Health Analytics'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
        future: _fetchUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading data: ${snapshot.error}'),
            );
          }

          final data = snapshot.data ?? {};
          final gingivitisData = data['gingivitis'] ?? [];
          final calculusData = data['calculus'] ?? [];

          if (gingivitisData.isEmpty && calculusData.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No dental health data available',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Take some scans to start tracking your progress',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (gingivitisData.isNotEmpty) ...[
                    _buildGingivitisOverview(gingivitisData),
                    const SizedBox(height: 16),
                  ],
                  if (calculusData.isNotEmpty) ...[
                    _buildCalculusOverview(calculusData),
                    const SizedBox(height: 16),
                  ],
                  if (gingivitisData.isNotEmpty || calculusData.isNotEmpty) ...[
                    _buildStatusSummary(gingivitisData, calculusData),
                    const SizedBox(height: 16),
                    _buildRecommendations(data),
                    const SizedBox(height: 16),
                    _buildScanHistory(gingivitisData, calculusData),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildScanHistory(
    List<Map<String, dynamic>> gingivitisData,
    List<Map<String, dynamic>> calculusData,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Scan History',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Result')),
                  DataColumn(label: Text('Severity/Confidence')),
                ],
                rows: [
                  ...gingivitisData.map((scan) => DataRow(
                        cells: [
                          DataCell(Text(DateFormat('MMM d, y')
                              .format(scan['timestamp']))),
                          const DataCell(Text('Gingivitis')),
                          DataCell(Text(
                              scan['hasGingivitis'] ? 'Detected' : 'Healthy')),
                          DataCell(Text(scan['maxSeverity'] != null
                              ? _getSeverityText(scan['maxSeverity'])
                              : 'N/A')),
                        ],
                      )),
                  ...calculusData.map((scan) => DataRow(
                        cells: [
                          DataCell(Text(DateFormat('MMM d, y')
                              .format(scan['timestamp']))),
                          const DataCell(Text('Calculus')),
                          DataCell(Text(scan['topPrediction'] ?? 'Unknown')),
                          DataCell(Text(
                              '${(scan['confidence'] * 100).toStringAsFixed(1)}%')),
                        ],
                      )),
                ]..sort((a, b) => (b.cells[0].child as Text)
                    .data!
                    .compareTo((a.cells[0].child as Text).data!)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
