import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../design/glass.dart';

class HomeScreen extends StatefulWidget {
  final String? refreshTrigger;
  
  const HomeScreen({super.key, this.refreshTrigger});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  Map<String, dynamic> briefData = {};
  List<dynamic> todayItems = [];
  List<dynamic> allHabits = [];
  List<dynamic> allTasks = [];
  bool isLoading = true;
  String? lastRefreshTrigger;
  DateTime selectedDate = DateTime.now();

  // Date helpers
  String formatDate(DateTime date) => date.toIso8601String().split('T')[0];
  
  List<DateTime> get weekDates {
    final startOfWeek = selectedDate.subtract(Duration(days: selectedDate.weekday % 7));
    return List.generate(7, (index) => startOfWeek.add(Duration(days: index)));
  }

  @override
  void initState() {
    super.initState();
    lastRefreshTrigger = widget.refreshTrigger;
    _loadBrief();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshTrigger != null && 
        widget.refreshTrigger != lastRefreshTrigger) {
      print('🔄 Home screen refreshing due to habit selection');
      lastRefreshTrigger = widget.refreshTrigger;
      _loadBrief();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadBrief();
      });
    }
  }

  @override
  void didPopNext() {
    _loadBrief();
  }

  Future<void> _loadBrief() async {
    try {
      apiClient.setAuthToken('valid-token');
      final brief = await apiClient.getBriefToday();
      
      print('📋 Brief loaded: ${brief.keys}');
      print('📋 Today items count: ${(brief['today'] as List?)?.length ?? 0}');
      print('📋 Raw today data: ${brief['today']}');
      
      // Load habits and tasks separately
      final habitsResult = await apiClient.getHabits();
      final tasksResult = await apiClient.getTasks();
      
      // Fallback: if today is empty but habits exist, use a subset of habits as today
      List<dynamic> today = brief['today'] ?? [];
      if (today.isEmpty && brief['habits'] != null) {
        final habits = brief['habits'] as List;
        print('📋 Today is empty, using fallback with ${habits.length} habits');
        today = habits.take(3).map((habit) => {
          'id': habit['id'],
          'name': habit['title'] ?? habit['name'],
          'type': 'habit',
          'completed': habit['status'] == 'completed',
          'streak': habit['streak'] ?? 0,
        }).toList();
        print('📋 Fallback today items: ${today.length}');
      }
      
      setState(() {
        briefData = brief;
        todayItems = today;
        allHabits = habitsResult;
        allTasks = tasksResult;
        isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading brief: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _completeTodayItem(Map<String, dynamic> item) async {
    try {
      if (item['type'] == 'habit') {
        await apiClient.tickHabit(item['id']);
      } else {
        await apiClient.completeTask(item['id']);
      }
      
      await apiClient.deselectForToday(item['id']);
      
      setState(() {
        final index = todayItems.indexWhere((i) => i['id'] == item['id']);
        if (index != -1) {
          todayItems[index]['completed'] = true;
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ ${item['name']} completed!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error completing item: $e')),
        );
      }
    }
  }

  Future<void> _removeTodayItem(Map<String, dynamic> item) async {
    try {
      await apiClient.deselectForToday(item['id']);
      setState(() {
        todayItems.removeWhere((i) => i['id'] == item['id']);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed ${item['name']} from today')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing item: $e')),
        );
      }
    }
  }

  Widget _buildCalendarStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Month/Year with navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => setState(() {
                  selectedDate = selectedDate.subtract(const Duration(days: 7));
                }),
                icon: const Icon(Icons.chevron_left, color: Colors.white70),
              ),
              Text(
                '${_monthName(selectedDate.month)} ${selectedDate.year}',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              IconButton(
                onPressed: () => setState(() {
                  selectedDate = selectedDate.add(const Duration(days: 7));
                }),
                icon: const Icon(Icons.chevron_right, color: Colors.white70),
              ),
            ],
          ),
          
          // Week day buttons
          Row(
            children: weekDates.map((date) {
              final isSelected = formatDate(date) == formatDate(selectedDate);
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => selectedDate = date),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF10B981) : const Color(0xFF121816),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF34D399) : Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _dayAbbr(date.weekday),
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            color: isSelected ? Colors.black : Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRankCard() {
    final user = briefData['user'] ?? {};
    final streaksSummary = briefData['streaksSummary'] ?? {};
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D1B69), Color(0xFF11998E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rank: ${user['rank'] ?? 'Sergeant'}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Level ${user['level'] ?? 1} • Streak ${streaksSummary['overall'] ?? 0} days',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${user['xp'] ?? 0} XP',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_fire_department, color: Colors.orange, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Top 15% consistency',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMentorCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF10B981).withOpacity(0.15),
            const Color(0xFF18181B),
            Colors.black,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Row(
        children: [
          // Mentor avatar
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF5EEAD4), Color(0xFF047857)],
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(
              Icons.face,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'buddha',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Progress: 0%',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your consistency today determines your success tomorrow.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionsBox() {
    final missions = briefData['missions'] ?? [];
    final completedMissions = missions.where((m) => m['status'] == 'completed').length;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Text(
            'Today\'s Missions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$completedMissions / ${missions.length} complete',
              style: const TextStyle(
                color: Color(0xFF10B981),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaySection(String title, List<dynamic> items, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'No items for today',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...items.map((item) {
              final isCompleted = item['completed'] == true;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isCompleted 
                      ? color.withOpacity(0.2)
                      : const Color(0xFF2A2A2A),
                  borderRadius: BorderRadius.circular(12),
                  border: isCompleted ? Border.all(
                    color: color.withOpacity(0.5),
                    width: 1,
                  ) : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      isCompleted ? Icons.check_circle : icon,
                      color: isCompleted ? color : color.withOpacity(0.8),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isCompleted 
                                ? '✅ ${item['name'] ?? 'Item'}'
                                : item['name'] ?? 'Item',
                            style: TextStyle(
                              color: isCompleted ? color : Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              decoration: isCompleted 
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          if (item['type'] == 'habit' && !isCompleted) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.local_fire_department, color: Colors.orange, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  '${item['streak'] ?? 0} day streak',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                if (item['reminderTime'] != null) ...[
                                  const SizedBox(width: 12),
                                  const Icon(Icons.access_time, color: Colors.white70, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    item['reminderTime'],
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!isCompleted) ...[
                      ElevatedButton(
                        onPressed: () => _completeTodayItem(item),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          item['type'] == 'habit' ? 'Complete' : 'Done',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ] else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'COMPLETED',
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  String _monthName(int month) {
    const months = ['', 'January', 'February', 'March', 'April', 'May', 'June',
                   'July', 'August', 'September', 'October', 'November', 'December'];
    return months[month];
  }

  String _dayAbbr(int weekday) {
    const days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday];
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading && briefData.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Separate habits and tasks from today items
    final todayHabits = todayItems.where((item) => item['type'] == 'habit').toList();
    final todayTasks = todayItems.where((item) => item['type'] == 'task').toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F0E),
      body: RefreshIndicator(
        onRefresh: () async => _loadBrief(),
        child: ListView(
          children: [
            const SizedBox(height: 40),
            
            // Calendar strip
            _buildCalendarStrip(),
            
            const SizedBox(height: 24),
            
            // Rank card
            _buildRankCard(),
            
            const SizedBox(height: 16),
            
            // Mentor card
            _buildMentorCard(),
            
            const SizedBox(height: 16),
            
            // Missions box
            _buildMissionsBox(),
            
            const SizedBox(height: 24),
            
            // Today's Habits
            _buildTodaySection(
              'Today\'s Habits',
              todayHabits,
              const Color(0xFF0EA5E9),
              Icons.local_fire_department,
            ),
            
            // Today's Tasks
            _buildTodaySection(
              'Today\'s Tasks',
              todayTasks,
              const Color(0xFF10B981),
              Icons.task_alt,
            ),
            
            const SizedBox(height: 100), // Bottom padding
          ],
        ),
      ),
    );
  }
}
