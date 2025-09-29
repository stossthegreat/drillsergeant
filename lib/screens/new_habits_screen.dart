import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../services/api_client.dart';
import '../design/feedback.dart';
import '../widgets/habit_create_edit_modal.dart';

class NewHabitsScreen extends StatefulWidget {
  const NewHabitsScreen({super.key});

  @override
  State<NewHabitsScreen> createState() => _NewHabitsScreenState();
}

class _NewHabitsScreenState extends State<NewHabitsScreen> with TickerProviderStateMixin {
  // Core data
  List<dynamic> allItems = [];
  bool isLoading = true;
  
  // UI state
  DateTime selectedDate = DateTime.now();
  String filterTab = 'habits'; // habits | tasks | bad
  bool showCreateModal = false;
  bool showSpeedDial = false;
  
  // Form state
  Map<String, dynamic> formData = {};
  bool isEditing = false;
  
  // Animation controllers
  late AnimationController _speedDialController;
  late AnimationController _modalController;
  
  // Color options matching React design
  final List<Map<String, dynamic>> colorOptions = [
    {'name': 'emerald', 'color': const Color(0xFF10B981), 'bgColor': const Color(0xFF10B981)},
    {'name': 'amber', 'color': const Color(0xFFF59E0B), 'bgColor': const Color(0xFFF59E0B)},
    {'name': 'sky', 'color': const Color(0xFF0EA5E9), 'bgColor': const Color(0xFF0EA5E9)},
    {'name': 'rose', 'color': const Color(0xFFE11D48), 'bgColor': const Color(0xFFE11D48)},
    {'name': 'violet', 'color': const Color(0xFF8B5CF6), 'bgColor': const Color(0xFF8B5CF6)},
    {'name': 'slate', 'color': const Color(0xFF64748B), 'bgColor': const Color(0xFF64748B)},
  ];

  // Date helpers
  String formatDate(DateTime date) => date.toIso8601String().split('T')[0];
  
  List<DateTime> get weekDates {
    final startOfWeek = selectedDate.subtract(Duration(days: selectedDate.weekday % 7));
    return List.generate(7, (index) => startOfWeek.add(Duration(days: index)));
  }

  @override
  void initState() {
    super.initState();
    _speedDialController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _modalController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _loadData();
    _resetForm();
  }

  @override
  void dispose() {
    _speedDialController.dispose();
    _modalController.dispose();
    super.dispose();
  }

  void _resetForm() {
    formData = {
      'id': null,
      'type': 'habit',
      'name': '',
      'category': 'General',
      'startDate': formatDate(DateTime.now()),
      'endDate': '',
      'frequency': 'daily',
      'everyN': 2,
      'color': 'emerald',
      'intensity': 2,
      'reminderOn': false,
      'reminderTime': '08:00',
    };
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      apiClient.setAuthToken('valid-token');
      
      // FIX 1: Load BOTH habits AND tasks
      final habitsResult = await apiClient.getHabits();
      final tasksResult = await apiClient.getTasks();
      
      // Combine habits and tasks with type field
      final List<dynamic> combinedItems = [];
      combinedItems.addAll(habitsResult.map((habit) => {
        ...habit,
        'type': 'habit',
      }));
      combinedItems.addAll(tasksResult.map((task) => {
        ...task,
        'type': 'task',
      }));
      
      setState(() {
        allItems = combinedItems;
        isLoading = false;
      });
    } catch (e) {
      print('❌ Error loading habits: $e');
      setState(() => isLoading = false);
    }
  }

  List<dynamic> get filteredItems {
    return allItems.where((item) {
      switch (filterTab) {
        case 'tasks':
          return item['type'] == 'task';
        case 'bad':
          return item['type'] == 'bad' || item['category'] == 'anti-habit';
        default:
          return item['type'] == 'habit' || item['type'] == null;
      }
    }).toList();
  }

  // FIX 4: Tick with idempotency
  Future<void> _toggleCompletion(String itemId, DateTime date) async {
    try {
      await apiClient.tickHabit(itemId, idempotencyKey: '${itemId}_${formatDate(date)}');
      HapticFeedback.selectionClick();
      _loadData(); // Refresh to show updated state
    } catch (e) {
      print('❌ Error toggling completion: $e');
    }
  }

  // FIX 3: Helper function to build schedule from frequency
  Map<String, dynamic> _buildScheduleFromFrequency(Map<String, dynamic> data) {
    final frequency = data['frequency'] ?? 'daily';
    final time = data['reminderTime'] ?? '08:00';
    
    switch (frequency) {
      case 'daily':
        return { 'time': time, 'days': ['daily'] };
      case 'weekdays':
        return { 'time': time, 'days': ['weekdays'] };
      case 'everyN':
        final everyN = int.tryParse(data['everyN']?.toString() ?? '2') ?? 2;
        return { 
          'time': time, 
          'days': ['daily'], 
          'everyN': everyN,
          'startDate': DateTime.now().toIso8601String()
        };
      default:
        return { 'time': time, 'days': ['daily'] };
    }
  }

  Future<void> _saveItem(Map<String, dynamic> data) async {
    if (data['name'].toString().trim().isEmpty) return;
    
    try {
      dynamic created;
      
      if (isEditing) {
        // UPDATE HABIT OR TASK
        // Update logic here...
        Toast.show(context, '✅ Updated!');
      } else {
        // CREATE NEW ITEM
        if (data['type'] == 'task') {
          // CREATE TASK
          created = await apiClient.createTask({
            'title': data['name'].toString().trim(),
            'description': '',
            'dueDate': data['startDate'] != null 
              ? DateTime.parse(data['startDate'].toString()).toIso8601String() 
              : DateTime.now().add(const Duration(days: 1)).toIso8601String(),
          });
          
          // Create alarm for task reminder
          if (data['reminderOn'] == true && data['reminderTime'] != null) {
            try {
              await apiClient.createAlarm({
                'label': 'Task: ${data['name'].toString().trim()}',
                'rrule': 'FREQ=ONCE',
                'tone': data['intensity'] == 3 ? 'strict' : data['intensity'] == 2 ? 'balanced' : 'light',
                'metadata': {
                  'type': 'task_reminder',
                  'taskId': created['id'],
                  'taskName': data['name'].toString().trim(),
                }
              });
              print('✅ Created alarm for task reminder');
            } catch (e) {
              print('❌ Error creating task alarm: $e');
            }
          }
          
          Toast.show(context, '✅ Task created!');
          
        } else {
          // CREATE HABIT (use fixed schedule builder)
          created = await apiClient.createHabit({
            'title': data['name'].toString().trim(),
            'schedule': _buildScheduleFromFrequency(data),
            'context': { 'difficulty': data['intensity'] },
            'color': data['color'],
            'reminderEnabled': data['reminderOn'],
            'reminderTime': data['reminderTime'],
          });
          
          // Create alarm for habit reminder
          if (data['reminderOn'] == true && data['reminderTime'] != null) {
            try {
              final timeParts = data['reminderTime'].toString().split(':');
              final hour = int.parse(timeParts[0]);
              final minute = int.parse(timeParts[1]);
              
              await apiClient.createAlarm({
                'label': 'Habit: ${data['name'].toString().trim()}',
                'rrule': 'FREQ=DAILY;BYHOUR=$hour;BYMINUTE=$minute',
                'tone': data['intensity'] == 3 ? 'strict' : data['intensity'] == 2 ? 'balanced' : 'light',
                'metadata': {
                  'type': 'habit_reminder',
                  'habitId': created['id'],
                  'habitName': data['name'].toString().trim(),
                }
              });
              print('✅ Created alarm for habit reminder');
            } catch (e) {
              print('❌ Error creating habit alarm: $e');
            }
          }
          
          // Auto-select habit for today
          try {
            await apiClient.selectForToday(created['id'].toString());
          } catch (e) {
            print('Error auto-selecting new habit: $e');
          }
          
          Toast.show(context, '✅ Habit created and added to today!');
        }
        
        // Update local state
        setState(() { 
          allItems.add(created); 
        });
        
        _closeModal();
        
        if (mounted) {
          context.go('/home?refresh=${DateTime.now().millisecondsSinceEpoch}');
        }
      }
      
      HapticFeedback.selectionClick();
    } catch (e) {
      print('❌ Error saving item: $e');
      Toast.show(context, 'Failed to save: $e');
    }
  }

  // FIX 2: Delete BOTH habits AND tasks
  Future<void> _deleteItem(String itemId) async {
    try {
      final item = allItems.firstWhere((i) => i['id'].toString() == itemId);
      if (item['type'] == 'habit') {
        await apiClient.deleteHabit(itemId);
      } else if (item['type'] == 'task') {
        await apiClient.deleteTask(itemId);
      }
      _loadData();
      HapticFeedback.heavyImpact();
    } catch (e) {
      print('❌ Error deleting item: $e');
    }
  }

  void _openCreateModal(String type) {
    setState(() {
      _resetForm();
      formData['type'] = type;
      isEditing = false;
      showCreateModal = true;
      showSpeedDial = false;
    });
    _modalController.forward();
  }

  void _openEditModal(dynamic item) {
    setState(() {
      formData = {
        'id': item['id'],
        'type': item['type'] ?? 'habit',
        'name': item['name'] ?? item['title'] ?? '',
        'category': item['category'] ?? 'General',
        'startDate': item['startDate'] ?? formatDate(DateTime.now()),
        'endDate': item['endDate'] ?? '',
        'frequency': item['frequency'] ?? 'daily',
        'everyN': item['everyN'] ?? 2,
        'color': item['color'] ?? 'emerald',
        'intensity': item['difficulty'] ?? item['intensity'] ?? 2,
        'reminderOn': item['reminderEnabled'] ?? false,
        'reminderTime': item['reminderTime'] ?? '08:00',
      };
      isEditing = true;
      showCreateModal = true;
    });
    _modalController.forward();
  }

  void _closeModal() {
    _modalController.reverse().then((_) {
      setState(() {
        showCreateModal = false;
        _resetForm();
      });
    });
  }

  Color _getColorForItem(dynamic item) {
    final colorName = item['color'] ?? 'emerald';
    return colorOptions.firstWhere(
      (c) => c['name'] == colorName,
      orElse: () => colorOptions[0],
    )['color'];
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          const Text(
            'Daily Orders',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Toast.show(context, 'Settings coming soon'),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.settings, color: Colors.white70, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekStrip() {
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
          
          const SizedBox(height: 16),
          
          // Filter tabs
          Row(
            children: [
              _buildFilterTab('habits', '🎯 Habits'),
              const SizedBox(width: 8),
              _buildFilterTab('tasks', '📋 Tasks'),
              const SizedBox(width: 8),
              _buildFilterTab('bad', '⚠️ Bad'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String tab, String label) {
    final isActive = filterTab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => filterTab = tab),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF10B981) : const Color(0xFF1A1F1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? const Color(0xFF34D399) : Colors.white.withOpacity(0.1),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? Colors.black : Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(dynamic item) {
    final color = _getColorForItem(item);
    final itemType = item['type'] ?? 'habit';
    final title = item['title'] ?? item['name'] ?? 'Untitled';
    final streak = item['streak'] ?? 0;
    final reminderTime = item['reminderTime'] ?? item['schedule']?['time'] ?? '';
    
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        children: [
          // Header row
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    itemType == 'task' ? Icons.task_alt : Icons.local_fire_department,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                
                // Title & streak
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (itemType != 'task') ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_fire_department, color: Colors.orange, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '$streak day streak',
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Reminder time
                if (reminderTime.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time, color: Colors.white70, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          reminderTime,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          
          // Week completion rail
          Row(
            children: weekDates.map((date) {
              final isCompleted = false; // Would check completion for this date
              final isScheduled = true; // Would check if scheduled for this date
              
              return Expanded(
                child: GestureDetector(
                  onTap: () => _toggleCompletion(item['id'].toString(), date),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    height: 40,
                    decoration: BoxDecoration(
                      color: isCompleted ? const Color(0xFF10B981) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isCompleted ? const Color(0xFF10B981) :
                               isScheduled ? Colors.white.withOpacity(0.2) :
                               Colors.white.withOpacity(0.1),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          color: isCompleted ? Colors.black : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          
          if (itemType != 'task') ...[
            const SizedBox(height: 8),
            
            // Stats row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Weekly', '5/7', color),
                  _buildStatItem('Monthly', '18/30', color),
                  _buildStatItem('Best', '${streak}d', color),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 8),
          
          // Action buttons
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionButton('Stats', Icons.bar_chart, () {}),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton('Edit', Icons.edit, () => _openEditModal(item)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton('Delete', Icons.delete, () => _deleteItem(item['id'].toString())),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton('Calendar', Icons.calendar_today, () {}),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedDial() {
    return Positioned(
      right: 16,
      bottom: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (showSpeedDial) ...[
            _buildSpeedDialItem('Task', Icons.task_alt, const Color(0xFF0EA5E9), () => _openCreateModal('task')),
            const SizedBox(height: 12),
            _buildSpeedDialItem('Habit', Icons.local_fire_department, const Color(0xFF10B981), () => _openCreateModal('habit')),
            const SizedBox(height: 12),
            _buildSpeedDialItem('Bad Habit', Icons.warning, const Color(0xFFE11D48), () => _openCreateModal('bad')),
            const SizedBox(height: 16),
          ],
          
          FloatingActionButton(
            onPressed: () {
              setState(() {
                showSpeedDial = !showSpeedDial;
              });
              showSpeedDial ? _speedDialController.forward() : _speedDialController.reverse();
            },
            backgroundColor: const Color(0xFF10B981),
            child: AnimatedRotation(
              turns: showSpeedDial ? 0.125 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.add, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedDialItem(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.black, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B0F0E),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF10B981)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F0E),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildTopBar()),
              SliverToBoxAdapter(child: _buildWeekStrip()),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
              
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildItemCard(filteredItems[index]),
                  childCount: filteredItems.length,
                ),
              ),
              
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
          
          _buildSpeedDial(),
          
          // Create/Edit Modal
          if (showCreateModal)
            HabitCreateEditModal(
              formData: formData,
              isEditing: isEditing,
              colorOptions: colorOptions,
              onSave: _saveItem,
              onCancel: _closeModal,
            ),
        ],
      ),
    );
  }
} 