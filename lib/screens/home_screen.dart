import 'package:agriaid/widgets/analytics.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';


class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  Map<String, dynamic>? userData;
  bool isLoading = true;
  Map<String, dynamic>? latestReadings;
  String selectedTimeRange = 'hour';

  // Controllers for data input
  final TextEditingController _temperatureController = TextEditingController();
  final TextEditingController _humidityController = TextEditingController();
  final TextEditingController _soilMoistureController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadLatestReadings();
  }

  @override
  void dispose() {
    _temperatureController.dispose();
    _humidityController.dispose();
    _soilMoistureController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final doc = await _authService.getUserData(_authService.currentUser!.uid);
      if (doc.exists) {
        setState(() {
          userData = doc.data() as Map<String, dynamic>;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error loading user data: $e');
    }
  }

  Future<void> _loadLatestReadings() async {
    try {
      final snapshot = await _firestore
          .collection('sensor_readings')
          .where('userId', isEqualTo: _authService.currentUser!.uid)
          .limit(50)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final sortedDocs = snapshot.docs.toList();
        sortedDocs.sort((a, b) {
          final aTime = a.data()['timestamp'];
          final bTime = b.data()['timestamp'];
          
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          
          if (aTime is Timestamp && bTime is Timestamp) {
            return bTime.compareTo(aTime);
          }
          
          if (aTime is String && bTime is String) {
            try {
              final aDate = DateTime.parse(aTime);
              final bDate = DateTime.parse(bTime);
              return bDate.compareTo(aDate);
            } catch (e) {
              return 0;
            }
          }
          
          return 0;
        });

        setState(() {
          latestReadings = sortedDocs.first.data();
        });
      } else {
        setState(() {
          latestReadings = null;
        });
      }
    } catch (e) {
      print('Error loading latest readings: $e');
      setState(() {
        latestReadings = null;
      });
    }
  }

  Future<void> _recordReading() async {
    if (_temperatureController.text.isEmpty ||
        _humidityController.text.isEmpty ||
        _soilMoistureController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill in all sensor readings'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final double temperature = double.parse(_temperatureController.text);
      final double humidity = double.parse(_humidityController.text);
      final double soilMoisture = double.parse(_soilMoistureController.text);

      if (humidity < 0 || humidity > 100) {
        throw Exception('Humidity must be between 0-100%');
      }
      if (soilMoisture < 0 || soilMoisture > 100) {
        throw Exception('Soil moisture must be between 0-100%');
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(),
        ),
      );

      await _firestore.collection('sensor_readings').add({
        'userId': _authService.currentUser!.uid,
        'temperature': temperature,
        'humidity': humidity,
        'soilMoisture': soilMoisture,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': DateTime.now().toIso8601String(),
      });

      _temperatureController.clear();
      _humidityController.clear();
      _soilMoistureController.clear();

      Navigator.of(context).pop();
      Navigator.of(context).pop();

      await _loadLatestReadings();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sensor reading recorded successfully!'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRecordDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.sensors, color: Colors.green[700]),
              SizedBox(width: 8),
              Text('Record Sensor Data'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _temperatureController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Temp (°C)',
                    prefixIcon: Icon(Icons.thermostat),
                    border: OutlineInputBorder(),
                    hintText: 'e.g., 25.5',
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _humidityController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Humidity (%)',
                    prefixIcon: Icon(Icons.water_drop),
                    border: OutlineInputBorder(),
                    hintText: 'e.g., 65.0',
                  ),
                ),
                SizedBox(height: 16),
                TextField(
                  controller: _soilMoistureController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Soil Moisture (%)',
                    prefixIcon: Icon(Icons.grass),
                    border: OutlineInputBorder(),
                    hintText: 'e.g., 45.0',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _recordReading,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
              ),
              child: Text('Record'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _signOut() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Sign Out'),
          content: Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _authService.signOut();
              },
              child: Text('Sign Out'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        );
      },
    );
  }

  void _navigateToAnalytics() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnalyticsScreen(userId: _authService.currentUser!.uid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[50],
      appBar: AppBar(
        title: Text(
          'AgriAid Monitor',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.analytics),
            onPressed: _navigateToAnalytics,
            tooltip: 'View Analytics',
          ),
          PopupMenuButton(
            icon: Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'logout') {
                _signOut();
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Sign Out'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _loadUserData();
                await _loadLatestReadings();
              },
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeCard(),
                    SizedBox(height: 24),
                    _buildLatestReadingsSection(),
                    SizedBox(height: 24),
                    _buildQuickActionsSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWelcomeCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.green[400]!, Colors.green[600]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  child: Icon(
                    Icons.agriculture,
                    size: 35,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back!',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        userData?['fullName'] ?? 'Farmer',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'Monitor your farm\'s environmental conditions',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLatestReadingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Latest Readings',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.green[800],
          ),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildSensorCard(
                title: 'Temp',
                value: latestReadings?['temperature']?.toStringAsFixed(1) ?? '--',
                unit: '°C',
                icon: Icons.thermostat,
                color: Colors.orange,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildSensorCard(
                title: 'Humidity',
                value: latestReadings?['humidity']?.toStringAsFixed(1) ?? '--',
                unit: '%',
                icon: Icons.water_drop,
                color: Colors.blue,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        _buildSensorCard(
          title: 'Soil Moisture',
          value: latestReadings?['soilMoisture']?.toStringAsFixed(1) ?? '--',
          unit: '%',
          icon: Icons.grass,
          color: Colors.brown,
          isFullWidth: true,
        ),
        
        if (latestReadings != null) 
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Last updated: ${_formatTimestamp(latestReadings!['timestamp'])}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.green[800],
          ),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _showRecordDialog,
                icon: Icon(Icons.add_circle_outline),
                label: Text('Record Data'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[700],
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _navigateToAnalytics,
                icon: Icon(Icons.analytics),
                label: Text('View Analytics'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSensorCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
    bool isFullWidth = false,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: isFullWidth ? double.infinity : null,
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: color,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    
    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is String) {
      try {
        dateTime = DateTime.parse(timestamp);
      } catch (e) {
        return 'Unknown';
      }
    } else {
      return 'Unknown';
    }
    
    final DateTime now = DateTime.now();
    final Duration difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}