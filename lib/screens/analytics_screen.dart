import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

    final gingivitisSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('gingivitis_detection')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .get();

    final calculusSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('calculus_detection')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .get();

    final plaqueSnapshot = await _firestore
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
      'plaque': plaqueSnapshot.docs
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
      color: Colors.white,
      elevation: 0,
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

  Widget _buildPlaqueOverview(List<Map<String, dynamic>> data) {
    if (data.isEmpty) {
      return _buildEmptyState('No plaque detection history available');
    }

    final latestScan = data.first;
    final resultImageUrl = latestScan['resultImageUrl'];

    return Card(
      color: Colors.white,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Plaque Status',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: resultImageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(resultImageUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: resultImageUrl == null
                      ? Icon(
                          Icons.image_not_supported,
                          color: Colors.grey[400],
                          size: 32,
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Last Scan',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Date: ${DateFormat('MMM d, y').format(latestScan['timestamp'])}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              color: Color(0xFFE75480),
                              margin: EdgeInsets.only(right: 4),
                            ),
                            Text('Plaque'),
                            SizedBox(width: 16),
                            Container(
                              width: 16,
                              height: 16,
                              color: Color(0xFF74EE15),
                              margin: EdgeInsets.only(right: 4),
                            ),
                            Text('Calculus'),
                          ],
                        ),
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
      color: Colors.white,
      elevation: 0,
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

  Widget _buildStatusSummary(
      List<Map<String, dynamic>> gingivitisData,
      List<Map<String, dynamic>> calculusData,
      List<Map<String, dynamic>> plaqueData) {
    return Card(
      color: Colors.white,
      elevation: 0,
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
            _buildOverallStatus(gingivitisData, calculusData, plaqueData),
            const Divider(height: 32),
            _buildImprovementTracking(gingivitisData, calculusData, plaqueData),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallStatus(
      List<Map<String, dynamic>> gingivitisData,
      List<Map<String, dynamic>> calculusData,
      List<Map<String, dynamic>> plaqueData) {
    final hasGingivitis =
        gingivitisData.isNotEmpty && gingivitisData.first['hasGingivitis'];
    final hasCalculus = calculusData.isNotEmpty &&
        calculusData.first['topPrediction']
            .toString()
            .toLowerCase()
            .contains('calculus');
    final hasPlaque =
        plaqueData.isNotEmpty && plaqueData.first['resultImageUrl'] != null;

    final overallStatus = !hasGingivitis && !hasCalculus && !hasPlaque
        ? 'Healthy'
        : (hasGingivitis && hasCalculus || hasPlaque)
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

  Widget _buildImprovementTracking(
      List<Map<String, dynamic>> gingivitisData,
      List<Map<String, dynamic>> calculusData,
      List<Map<String, dynamic>> plaqueData) {
    bool hasGingivitisData = gingivitisData.length >= 2;
    bool hasCalculusData = calculusData.length >= 2;

    if (!hasGingivitisData && !hasCalculusData) {
      return Container();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Progress Tracking',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (hasGingivitisData) ...[
          _buildProgressItem(
              'Gingivitis', _calculateProgress(gingivitisData, 'gingivitis')),
          const SizedBox(height: 8),
        ],
        if (hasCalculusData) ...[
          _buildProgressItem(
              'Calculus', _calculateProgress(calculusData, 'calculus')),
          const SizedBox(height: 8),
        ],
        // if (hasPlaqueData) ...[
        //   _buildProgressItem(
        //       'Plaque', _calculateProgress(plaqueData, 'plaque')),
        // ],
      ],
    );
  }

  Widget _buildRecommendations(Map<String, List<Map<String, dynamic>>> data) {
    final gingivitisData = data['gingivitis'] ?? [];
    final calculusData = data['calculus'] ?? [];
    final plaqueData = data['plaque'] ?? [];

    if (gingivitisData.isEmpty && calculusData.isEmpty && plaqueData.isEmpty) {
      return Card(
        color: Colors.white,
        elevation: 0,
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
    final hasPlaque =
        plaqueData.isNotEmpty && plaqueData.first['resultImageUrl'] != null;

    return Card(
      color: Colors.white,
      elevation: 0,
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
            if (hasPlaque) ...[
              _buildRecommendationItem(
                'Improve oral hygiene',
                'Detected plaque indicates need for better brushing and flossing routine.',
                Icons.cleaning_services,
              ),
            ],
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
                !hasPlaque &&
                (gingivitisData.isNotEmpty ||
                    calculusData.isNotEmpty ||
                    plaqueData.isNotEmpty))
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
    } else if (type == 'calculus') {
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
          (currentHasLightCalculus && previousHasheavyCalculus)) {
        return 'Improving';
      }
      if ((currentHasheavyCalculus &&
              (previousHasLightCalculus || previousHasNoCalculus)) ||
          (currentHasLightCalculus && previousHasNoCalculus)) {
        return 'Worsening';
      }
    }
    return 'Stable';
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

  Widget _buildEmptyState(String message) {
    return Card(
      color: Colors.white,
      elevation: 0,
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
    final primaryColor = Theme.of(context).primaryColor;
    final cardDecoration = BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: primaryColor,
        width: 1,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
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
          final plaqueData = data['plaque'] ?? [];

          if (gingivitisData.isEmpty &&
              calculusData.isEmpty &&
              plaqueData.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No dental health data available',
                    style: TextStyle(
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Take some scans to start tracking your progress',
                    style: TextStyle(
                      fontSize: 14,
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
                  if (plaqueData.isNotEmpty) ...[
                    Container(
                      decoration: cardDecoration,
                      child: _buildPlaqueOverview(plaqueData),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (gingivitisData.isNotEmpty) ...[
                    Container(
                      decoration: cardDecoration,
                      child: _buildGingivitisOverview(gingivitisData),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (calculusData.isNotEmpty) ...[
                    Container(
                      decoration: cardDecoration,
                      child: _buildCalculusOverview(calculusData),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (gingivitisData.isNotEmpty ||
                      calculusData.isNotEmpty ||
                      plaqueData.isNotEmpty) ...[
                    Container(
                      decoration: cardDecoration,
                      child: _buildStatusSummary(
                          gingivitisData, calculusData, plaqueData),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: cardDecoration,
                      child: _buildRecommendations(data),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: cardDecoration,
                      child: _buildScanHistory(
                          gingivitisData, calculusData, plaqueData),
                    ),
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
    List<Map<String, dynamic>> plaqueData,
  ) {
    final allScans = [
      ...gingivitisData.map((scan) => ({
            ...scan,
            'type': 'Gingivitis',
            'result': scan['hasGingivitis'] ? 'Detected' : 'Healthy',
          })),
      ...calculusData.map((scan) => ({
            ...scan,
            'type': 'Calculus',
            'result': scan['topPrediction'] ?? 'Unknown',
          })),
      ...plaqueData.map((scan) => ({
            ...scan,
            'type': 'Plaque',
            'result': 'View Result',
            'hasImage': scan['resultImageUrl'] != null,
          })),
    ];

    allScans.sort((a, b) =>
        (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));

    return Card(
      color: Colors.white,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Scan History',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  '${allScans.length} scans',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(
                      Colors.grey.shade50,
                    ),
                    dataRowMaxHeight: 64,
                    dataRowMinHeight: 64,
                    columnSpacing: 32,
                    columns: [
                      DataColumn(
                        label: Row(
                          children: [
                            Icon(Icons.calendar_today,
                                size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            const Text('Date'),
                          ],
                        ),
                      ),
                      DataColumn(
                        label: Row(
                          children: [
                            Icon(Icons.category,
                                size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            const Text('Type'),
                          ],
                        ),
                      ),
                      DataColumn(
                        label: Row(
                          children: [
                            Icon(Icons.assessment,
                                size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            const Text('Result'),
                          ],
                        ),
                      ),
                    ],
                    rows: allScans.map((scan) {
                      final scanType = scan['type'] as String;
                      final result = scan['result'] as String;

                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              DateFormat('MMM d, y').format(scan['timestamp']),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getScanTypeColor(scanType),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                scanType,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            scanType == 'Plaque' && scan['hasImage']
                                ? TextButton.icon(
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => Dialog(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              AppBar(
                                                title:
                                                    const Text('Scan Result'),
                                                leading: IconButton(
                                                  icon: const Icon(Icons.close),
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                ),
                                              ),
                                              Image.network(
                                                scan['resultImageUrl'],
                                                fit: BoxFit.contain,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.image,
                                        size: 20, color: Colors.blue),
                                    label: const Text('View Result',
                                        style: TextStyle(color: Colors.blue)),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12),
                                    ),
                                  )
                                : Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _getResultColor(result),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(result),
                                    ],
                                  ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getScanTypeColor(String type) {
    switch (type) {
      case 'Gingivitis':
        return Colors.purple[400]!;
      case 'Calculus':
        return Colors.blue[400]!;
      case 'Plaque':
        return Colors.teal[400]!;
      default:
        return Colors.grey[400]!;
    }
  }

  Color _getResultColor(String result) {
    switch (result.toLowerCase()) {
      case 'healthy':
        return Colors.green;
      case 'detected':
      case 'heavy calculus':
      case 'light calculus':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
