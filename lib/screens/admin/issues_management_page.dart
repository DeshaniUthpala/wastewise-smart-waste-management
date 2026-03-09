import 'package:flutter/material.dart';
import '../../models/pickup_request_model.dart';
import '../../models/report_model.dart';
import '../../services/database_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/date_formatter.dart';

class IssuesManagementPage extends StatefulWidget {
  const IssuesManagementPage({super.key});

  @override
  State<IssuesManagementPage> createState() => _IssuesManagementPageState();
}

class _IssuesManagementPageState extends State<IssuesManagementPage> {
  final DatabaseService _databaseService = DatabaseService();

  String searchQuery = '';
  String filterStatus = 'all';
  bool showRequests = true;
  bool showIssues = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7F9),
      body: SafeArea(
        child: StreamBuilder<Map<String, Map<String, dynamic>>>(
          stream: _databaseService.getAllUserDisplayMapStream(),
          builder: (context, usersSnapshot) {
            final usersMap = usersSnapshot.data ?? {};
            final assignableDrivers = usersMap.values.where((u) {
              return (u['role'] == 'driver') && (u['isActive'] != false);
            }).toList();

            return CustomScrollView(
              slivers: [
                _buildSliverHeader(),
                _buildSliverStats(),
                _setSliverFilters(),
                
                // UNIFIED CONTENT
                _buildCombinedContent(usersMap, assignableDrivers),
                
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSliverHeader() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Operations Center',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A1C1E),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage real-time pickup requests and reported issues',
              style: TextStyle(color: Colors.grey[600], fontSize: 15),
            ),
            const SizedBox(height: 20),
            _buildSearchBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        onChanged: (value) => setState(() => searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Search requests, issues, citizens...',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          prefixIcon: Icon(Icons.search, color: AppColors.accentGreen),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          suffixIcon: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.accentGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: PopupMenuButton<String>(
              icon: Icon(Icons.filter_list, color: AppColors.accentGreen, size: 20),
              onSelected: (value) => setState(() => filterStatus = value),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'all', child: Text('All Statuses')),
                const PopupMenuItem(value: 'pending', child: Text('Pending')),
                const PopupMenuItem(value: 'assigned', child: Text('Assigned')),
                const PopupMenuItem(value: 'in_progress', child: Text('In Progress')),
                const PopupMenuItem(value: 'completed', child: Text('Completed')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSliverStats() {
    return SliverToBoxAdapter(
      child: StreamBuilder<List<PickupRequestModel>>(
        stream: _databaseService.getPickupRequestsStream(),
        builder: (context, reqSnap) {
          return StreamBuilder<List<ReportModel>>(
            stream: _databaseService.getReportsStream(),
            builder: (context, reportSnap) {
              final reqCount = reqSnap.data?.length ?? 0;
              final issueCount = reportSnap.data?.length ?? 0;
              
              if (reportSnap.hasError) {
                print('❌ StreamBuilder Report Error: ${reportSnap.error}');
              }
              
              final pendingReq = reqSnap.data?.where((r) => (r.status.toLowerCase().trim() == 'pending')).length ?? 0;
              final openIssues = reportSnap.data?.where((r) => (r.status.toLowerCase().trim() == 'open')).length ?? 0;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Row(
                  children: [
                    _buildStatCard('Pickups', reqCount.toString(), '$pendingReq Pending', Colors.blue),
                    const SizedBox(width: 16),
                    _buildStatCard('Issues', issueCount.toString(), '$openIssues Open', Colors.orange),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, String val, String subtitle, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.1), width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.analytics_outlined, color: color, size: 20),
            ),
            const SizedBox(height: 12),
            Text(val, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _setSliverFilters() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Row(
          children: [
             FilterChip(
              label: const Text('Pickup Requests'),
              selected: showRequests,
              selectedColor: AppColors.accentGreen.withOpacity(0.2),
              onSelected: (v) => setState(() => showRequests = v),
             ),
             const SizedBox(width: 8),
             FilterChip(
              label: const Text('Issue Reports'),
              selected: showIssues,
              selectedColor: AppColors.accentGreen.withOpacity(0.2),
              onSelected: (v) => setState(() => showIssues = v),
             ),
          ],
        ),
      ),
    );
  }

  Widget _buildCombinedContent(Map<String, Map<String, dynamic>> usersMap, List<Map<String, dynamic>> drivers) {
    return StreamBuilder<List<PickupRequestModel>>(
      stream: _databaseService.getPickupRequestsStream(),
      builder: (context, reqSnapshot) {
        return StreamBuilder<List<ReportModel>>(
          stream: _databaseService.getReportsStream(),
          builder: (context, issueSnapshot) {
            if (reqSnapshot.connectionState == ConnectionState.waiting || issueSnapshot.connectionState == ConnectionState.waiting) {
              return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
            }

            var requests = reqSnapshot.data ?? [];
            var issues = issueSnapshot.data ?? [];

            // FILTERING LOGIC
            if (filterStatus != 'all') {
              requests = requests.where((r) => r.status.toLowerCase().trim() == filterStatus.toLowerCase().trim()).toList();
              issues = issues.where((i) => i.status.toLowerCase().trim() == filterStatus.toLowerCase().trim()).toList();
            }

            final query = searchQuery.toLowerCase();
            if (query.isNotEmpty) {
               requests = requests.where((r) {
                  final name = _resolveUserName(r.citizenId, usersMap).toLowerCase();
                  return name.contains(query) || (r.location.address ?? '').toLowerCase().contains(query) || r.wasteType.toLowerCase().contains(query);
               }).toList();
               issues = issues.where((i) {
                  final name = _resolveUserName(i.reporterId, usersMap).toLowerCase();
                  return name.contains(query) || i.title.toLowerCase().contains(query) || i.description.toLowerCase().contains(query);
               }).toList();
            }

            final List<Widget> slivers = [];

            if (showRequests && requests.isNotEmpty) {
              slivers.add(const SliverPadding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
                sliver: SliverToBoxAdapter(child: Text('Pickup Requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              ));
              slivers.add(SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildRequestCard(requests[index], usersMap, drivers),
                    childCount: requests.length,
                  ),
                ),
              ));
            }

            if (showIssues && issues.isNotEmpty) {
              slivers.add(const SliverPadding(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 12),
                sliver: SliverToBoxAdapter(child: Text('Reported Issues', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              ));
              slivers.add(SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildIssueCard(issues[index], usersMap, drivers),
                    childCount: issues.length,
                  ),
                ),
              ));
            }

            if (requests.isEmpty && issues.isEmpty) {
              return SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('No records found', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                    ],
                  ),
                ),
              );
            }

            return SliverMainAxisGroup(slivers: slivers);
          },
        );
      },
    );
  }

  // --- CARD BUILDERS (Enhanced styling) ---

  Widget _buildRequestCard(PickupRequestModel req, Map<String, Map<String, dynamic>> usersMap, List<Map<String, dynamic>> drivers) {
    final citizenName = _resolveUserName(req.citizenId, usersMap);
    final assigned = req.driverId == null ? 'Pending Assignment' : _resolveUserName(req.driverId!, usersMap);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.03),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                CircleAvatar(backgroundColor: Colors.blue.withOpacity(0.1), child: const Icon(Icons.local_shipping, color: Colors.blue, size: 20)),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(citizenName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Row(
                      children: [
                        Text(req.wasteType.toUpperCase(), style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        if (req.status == 'completed' && req.completedDate != null)
                           Text('• Completed in ${DateFormatter.formatDuration(req.requestedDate, req.completedDate!)}', 
                             style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold))
                        else
                          Text('• ${DateFormatter.timeAgo(req.requestedDate)}', style: TextStyle(fontSize: 11, color: Colors.blue[400])),
                      ],
                    ),
                  ],
                )),
                _statusChip(req.status),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _infoRow(Icons.place_outlined, _formatLocation(req)),
                const SizedBox(height: 8),
                _infoRow(Icons.person_pin_outlined, assigned),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => _showPickupDetails(req, usersMap), child: const Text('View'))),
                const SizedBox(width: 8),
                Expanded(child: ElevatedButton(onPressed: () => _showAssignPickupDialog(req, drivers), child: const Text('Assign'))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueCard(ReportModel issue, Map<String, Map<String, dynamic>> usersMap, List<Map<String, dynamic>> drivers) {
    final reporterName = _resolveUserName(issue.reporterId, usersMap);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.03),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                CircleAvatar(backgroundColor: Colors.orange.withOpacity(0.1), child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20)),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(issue.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Row(
                      children: [
                        Text('By $reporterName', style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        if (issue.status == 'closed' || issue.status == 'resolved')
                          if (issue.resolvedAt != null)
                             Text('• Resolved in ${DateFormatter.formatDuration(issue.createdAt, issue.resolvedAt!)}', 
                               style: const TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold))
                          else
                             const Text('• Resolved', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold))
                        else
                          Text('• ${DateFormatter.timeAgo(issue.createdAt)}', style: TextStyle(fontSize: 11, color: Colors.orange[400])),
                      ],
                    ),
                  ],
                )),
                _statusChip(issue.status),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(issue.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
          ),
           Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => _showIssueDetails(issue, usersMap), child: const Text('Details'))),
                const SizedBox(width: 8),
                Expanded(child: ElevatedButton(onPressed: () => _showAssignIssueDialog(issue, drivers), child: const Text('Assign'))),
                const SizedBox(width: 8),
                Expanded(child: ElevatedButton(onPressed: () => _showUpdateStatusDialog(issue), child: const Text('Status'))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    Color color = Colors.grey;
    if (status == 'pending' || status == 'open') color = Colors.orange;
    if (status == 'assigned' || status == 'in_progress') color = Colors.blue;
    if (status == 'completed' || status == 'resolved' || status == 'closed') color = Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
    );
  }

  Widget _infoRow(IconData icon, String val) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(child: Text(val, style: TextStyle(color: Colors.grey[600], fontSize: 13))),
      ],
    );
  }

  // --- LOGIC HELPER METHODS (Copy-pasted from original for functionality continuity) ---

  String _resolveUserName(String uid, Map<String, Map<String, dynamic>> usersMap) {
    final user = usersMap[uid];
    if (user != null) return user['name'] ?? uid;
    return uid;
  }

  String _formatLocation(PickupRequestModel req) {
    return req.location.address ?? 'Lat: ${req.location.latitude}';
  }

  void _showPickupDetails(PickupRequestModel req, Map<String, Map<String, dynamic>> usersMap) {
     showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pickup Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Citizen: ${_resolveUserName(req.citizenId, usersMap)}'),
            Text('Type: ${req.wasteType}'),
            Text('Status: ${req.status}'),
            const SizedBox(height: 8),
            Text('Address: ${req.location.address ?? 'N/A'}'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  void _showIssueDetails(ReportModel issue, Map<String, Map<String, dynamic>> usersMap) {
     showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(issue.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reporter: ${_resolveUserName(issue.reporterId, usersMap)}'),
            Text('Priority: ${issue.priority}'),
            const SizedBox(height: 8),
            Text(issue.description),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  void _showAssignPickupDialog(PickupRequestModel req, List<Map<String, dynamic>> drivers) {
    if (drivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active drivers available')));
      return;
    }
    String? selectedId = req.driverId;
    bool isAssigning = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Assign Driver'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: isAssigning 
            ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: drivers.length,
                  itemBuilder: (context, index) {
                    final d = drivers[index];
                    return RadioListTile<String>(
                      activeColor: AppColors.accentGreen,
                      value: d['uid']?.toString() ?? '',
                      groupValue: selectedId,
                      title: Text(d['name'] ?? 'Driver'),
                      subtitle: Text(d['role']?.toString().toUpperCase() ?? ''),
                      onChanged: (v) => setDialog(() => selectedId = v),
                    );
                  },
                ),
              ),
          actions: [
            TextButton(
              onPressed: isAssigning ? null : () => Navigator.pop(context), 
              child: const Text('Cancel')
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGreen, 
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: selectedId == null || isAssigning ? null : () async {
                setDialog(() => isAssigning = true);
                try {
                  if (req.id == null) {
                    throw Exception("Request ID is missing.");
                  }
                  await _databaseService.assignDriverToPickup(req.id!, selectedId!);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    setDialog(() => isAssigning = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Assign failed: ${e.toString()}'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: isAssigning 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Assign'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignIssueDialog(ReportModel issue, List<Map<String, dynamic>> drivers) {
    if (drivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active drivers available')));
      return;
    }
    String? selectedId = issue.assignedTo;
    bool isAssigning = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Assign Driver to Issue'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: isAssigning 
            ? const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: drivers.length,
                  itemBuilder: (context, index) {
                    final d = drivers[index];
                    return RadioListTile<String>(
                      activeColor: AppColors.accentGreen,
                      value: d['uid']?.toString() ?? '',
                      groupValue: selectedId,
                      title: Text(d['name'] ?? 'Driver'),
                      subtitle: Text(d['role']?.toString().toUpperCase() ?? ''),
                      onChanged: (v) => setDialog(() => selectedId = v),
                    );
                  },
                ),
              ),
          actions: [
            TextButton(
              onPressed: isAssigning ? null : () => Navigator.pop(context), 
              child: const Text('Cancel')
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGreen, 
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: selectedId == null || isAssigning ? null : () async {
                setDialog(() => isAssigning = true);
                try {
                  if (issue.id == null) {
                    throw Exception("Issue ID is missing.");
                  }
                  await _databaseService.assignDriverToReport(reportId: issue.id!, driverId: selectedId!);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    setDialog(() => isAssigning = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Assign failed: ${e.toString()}'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              child: isAssigning 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Assign'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpdateStatusDialog(ReportModel issue) {
    String status = issue.status;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Status'),
        content: DropdownButtonFormField<String>(
          value: status,
          items: ['open', 'in_progress', 'resolved', 'closed'].map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase()))).toList(),
          onChanged: (v) => status = v!,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await _databaseService.updateReportStatus(reportId: issue.id!, status: status);
              Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
}
