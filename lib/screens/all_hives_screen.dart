import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taskhive/models/hive_project.dart';
import 'package:taskhive/screens/hive_detail_screen.dart';

class AllHivesScreen extends StatefulWidget {
  final String teamId;
  
  const AllHivesScreen({super.key, required this.teamId});

  @override
  State<AllHivesScreen> createState() => _AllHivesScreenState();
}

class _AllHivesScreenState extends State<AllHivesScreen> {
  bool _isLoading = true;
  List<HiveProject> _hives = [];
  String _searchQuery = '';
  String _sortBy = 'name';
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _loadHives();
  }

  Future<void> _loadHives() async {
    setState(() => _isLoading = true);
    try {
      final hivesSnapshot = await FirebaseFirestore.instance
          .collection('projects')
          .where('teamId', isEqualTo: widget.teamId)
          .get();

      setState(() {
        _hives = hivesSnapshot.docs
            .map((doc) => HiveProject.fromFirestore(doc))
            .toList();
        _sortHives();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _sortHives() {
    switch (_sortBy) {
      case 'name':
        _hives.sort((a, b) => _sortAscending
            ? a.name.compareTo(b.name)
            : b.name.compareTo(a.name));
        break;
      case 'status':
        _hives.sort((a, b) => _sortAscending
            ? a.status.toString().compareTo(b.status.toString())
            : b.status.toString().compareTo(a.status.toString()));
        break;
    }
  }

  List<HiveProject> get _filteredHives {
    if (_searchQuery.isEmpty) return _hives;
    return _hives.where((hive) {
      final query = _searchQuery.toLowerCase();
      return hive.name.toLowerCase().contains(query) ||
          hive.description.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Hives'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHives,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search hives...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildHivesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHivesList() {
    final hives = _filteredHives;
    
    if (hives.isEmpty) {
      return Center(
        child: Text(_searchQuery.isEmpty ? 'No hives found' : 'No matches found'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: hives.length,
      itemBuilder: (context, index) {
        final hive = hives[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.hive, color: Colors.amber),
            title: Text(hive.name),
            subtitle: Text(hive.description),
            trailing: Text(hive.status.toString()),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => HiveDetailScreen(projectId: hive.id),
              ),
            ).then((_) => _loadHives()),
          ),
        );
      },
    );
  }
} 