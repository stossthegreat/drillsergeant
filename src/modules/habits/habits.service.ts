import { Injectable } from '@nestjs/common';

@Injectable()
export class HabitsService {
  private habits = [
    {
      id: 'habit-1',
      userId: 'demo-user-123',
      title: 'Morning Workout',
      streak: 7,
      schedule: { time: '07:00', days: ['mon', 'tue', 'wed', 'thu', 'fri'] },
      lastTick: null,
      context: { difficulty: 2, category: 'fitness', lifeDays: 0.5 },
      color: 'emerald',
      reminderEnabled: true,
      reminderTime: '07:00',
      createdAt: '2024-01-01T00:00:00Z'
    },
    {
      id: 'habit-2',
      userId: 'demo-user-123',
      title: 'Read 30 Minutes',
      streak: 30,
      schedule: { time: '20:00', days: ['daily'] },
      lastTick: null,
      context: { difficulty: 1, category: 'learning', lifeDays: 0.3 },
      color: 'sky',
      reminderEnabled: true,
      reminderTime: '20:00',
      createdAt: '2024-01-01T00:00:00Z'
    }
  ];

  async list(userId: string) {
    const userHabits = this.habits.filter(habit => habit.userId === userId);
    
    // Filter by schedule - only show habits that should appear today
    const today = new Date();
    const dayName = today.toLocaleDateString('en-US', { weekday: 'long' }).toLowerCase();
    const dayAbbr = today.toLocaleDateString('en-US', { weekday: 'short' }).toLowerCase();
    
    return userHabits.filter(habit => {
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
    });
  }

  async create(userId: string, habitData: any) {
    const newHabit = {
      id: `habit-${Date.now()}`,
      userId,
      title: habitData.title || habitData.name,
      streak: 0,
      schedule: habitData.schedule || { type: 'daily', days: ['daily'] },
      lastTick: null,
      context: habitData.context || { difficulty: 2 },
      color: habitData.color || 'emerald',
      reminderEnabled: habitData.reminderEnabled || false,
      reminderTime: habitData.reminderTime || '08:00',
      createdAt: new Date().toISOString(),
      ...habitData
    };
    
    this.habits.push(newHabit);
    return newHabit;
  }

  async tick(id: string, userId: string) {
    const habit = this.habits.find(h => h.id === id && h.userId === userId);
    if (!habit) {
      throw new Error('Habit not found');
    }
    
    const now = new Date();
    const today = now.toDateString(); // "Mon Sep 29 2025"
    
    // Check if already ticked today - THIS IS THE CRITICAL FIX
    const lastTickDate = habit.lastTick ? new Date(habit.lastTick).toDateString() : null;
    
    if (lastTickDate === today) {
      // Already ticked today - return current state (IDEMPOTENT)
      return { 
        ok: true, 
        idempotent: true, 
        streak: habit.streak, 
        timestamp: habit.lastTick,
        message: 'Already completed today'
      };
    }
    
    // Not ticked today - update it
    habit.lastTick = now.toISOString();
    habit.streak = (habit.streak || 0) + 1;
    
    console.log(`✅ Habit ${habit.title} ticked for ${today}. Streak: ${habit.streak}`);
    
    return { 
      ok: true, 
      idempotent: false, 
      streak: habit.streak, 
      timestamp: habit.lastTick,
      message: `Completed! Streak: ${habit.streak} days`
    };
  }

  async delete(id: string, userId: string) {
    const habitIndex = this.habits.findIndex(h => h.id === id && h.userId === userId);
    if (habitIndex === -1) {
      throw new Error('Habit not found');
    }
    
    const deletedHabit = this.habits.splice(habitIndex, 1)[0];
    console.log(`🗑️ Deleted habit: ${deletedHabit.title}`);
    
    return { ok: true, deleted: deletedHabit };
  }

  async update(id: string, userId: string, updateData: any) {
    const habit = this.habits.find(h => h.id === id && h.userId === userId);
    if (!habit) {
      throw new Error('Habit not found');
    }
    
    Object.assign(habit, updateData);
    return habit;
  }
}
