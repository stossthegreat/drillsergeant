import re

# Read the habits service file
with open('src/modules/habits/habits.service.ts', 'r') as f:
    content = f.read()

# Find the list method and replace the schedule filtering logic
old_filter = '''    return userHabits.filter(habit => {
      const schedule = habit.schedule;
      if (!schedule || !schedule.days) return true; // Show if no schedule
      
      const scheduleDays = schedule.days;
      
      // Check if today matches the schedule
      if (scheduleDays.includes('daily')) return true;
      if (scheduleDays.includes(dayName)) return true;
      if (scheduleDays.includes(dayAbbr)) return true;
      
      // Check weekday patterns
      if (scheduleDays.includes('weekdays') && today.getDay() >= 1 && today.getDay() <= 5) return true;
      if (scheduleDays.includes('weekends') && (today.getDay() === 0 || today.getDay() === 6)) return true;
      
      return false;
    });'''

new_filter = '''    return userHabits.filter(habit => {
      const schedule = habit.schedule;
      if (!schedule || !schedule.days) return true; // Show if no schedule
      
      const scheduleDays = schedule.days;
      
      // Check if today matches the schedule
      if (scheduleDays.includes('daily')) {
        // Check if it's an everyN schedule with duration
        if (schedule.everyN && schedule.startDate) {
          const startDate = new Date(schedule.startDate);
          const daysDiff = Math.floor((today.getTime() - startDate.getTime()) / (1000 * 60 * 60 * 24));
          const everyN = schedule.everyN || 1;
          return daysDiff % everyN === 0;
        }
        return true;
      }
      if (scheduleDays.includes(dayName)) return true;
      if (scheduleDays.includes(dayAbbr)) return true;
      
      // Check weekday patterns
      if (scheduleDays.includes('weekdays') && today.getDay() >= 1 && today.getDay() <= 5) return true;
      if (scheduleDays.includes('weekends') && (today.getDay() === 0 || today.getDay() === 6)) return true;
      
      return false;
    });'''

# Replace the old filter with the new one
content = content.replace(old_filter, new_filter)

# Write the file back
with open('src/modules/habits/habits.service.ts', 'w') as f:
    f.write(content)

print("Fixed backend schedule filtering logic")
