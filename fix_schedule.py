import re

# Read the file
with open('lib/screens/new_habits_screen.dart', 'r') as f:
    content = f.read()

# Find the habit creation section and replace it
old_schedule = """'schedule': { 'time': data['reminderTime'] ?? '08:00', 'days': ['daily'] },"""

new_schedule = """'schedule': _buildScheduleFromFrequency(data),"""

# Replace the schedule line
content = content.replace(old_schedule, new_schedule)

# Add the helper function before the habit creation
helper_function = '''
  // Helper function to build schedule from frequency
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
'''

# Find the right place to insert the helper function (before the habit creation)
insert_point = content.find('// CREATE HABIT (existing logic)')
if insert_point != -1:
    # Find the start of the function
    function_start = content.rfind('Future<void> _saveItem', 0, insert_point)
    if function_start != -1:
        # Find the opening brace
        brace_pos = content.find('{', function_start)
        if brace_pos != -1:
            # Insert the helper function
            content = content[:brace_pos + 1] + helper_function + content[brace_pos + 1:]

# Write the file back
with open('lib/screens/new_habits_screen.dart', 'w') as f:
    f.write(content)

print("Fixed schedule creation logic")
