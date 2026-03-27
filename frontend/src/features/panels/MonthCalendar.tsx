import { useEffect, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import {
  addMonths,
  formatMonthYear,
  getMonthCalendar,
  isSameDate,
  isSameMonth,
} from '../daily-state/date';
import { colors } from '../../theme/tokens';

type MonthCalendarProps = {
  selectedDate: string;
  onSelectDate: (dateKey: string) => void;
};

const weekLabels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

export function MonthCalendar({ selectedDate, onSelectDate }: MonthCalendarProps) {
  const [displayMonth, setDisplayMonth] = useState(selectedDate);

  useEffect(() => {
    if (!isSameMonth(displayMonth, selectedDate)) {
      setDisplayMonth(selectedDate);
    }
  }, [displayMonth, selectedDate]);

  const days = getMonthCalendar(displayMonth);

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.monthLabel}>{formatMonthYear(displayMonth).toUpperCase()}</Text>
        <View style={styles.controls}>
          <MonthButton label="<" onPress={() => setDisplayMonth(addMonths(displayMonth, -1))} />
          <MonthButton label=">" onPress={() => setDisplayMonth(addMonths(displayMonth, 1))} />
        </View>
      </View>

      <View style={styles.weekHeader}>
        {weekLabels.map((label) => (
          <Text key={label} style={styles.weekLabel}>
            {label}
          </Text>
        ))}
      </View>

      <View style={styles.grid}>
        {days.map((day) => (
          <Pressable
            key={day.dateKey}
            onPress={() => onSelectDate(day.dateKey)}
            style={({ pressed }) => [
              styles.dayCell,
              isSameDate(day.dateKey, selectedDate) && styles.dayCellActive,
              pressed && styles.dayCellPressed,
            ]}
          >
            <Text
              style={[
                styles.dayText,
                !day.inCurrentMonth && styles.dayTextMuted,
                isSameDate(day.dateKey, selectedDate) && styles.dayTextActive,
              ]}
            >
              {day.dayNumber}
            </Text>
          </Pressable>
        ))}
      </View>
    </View>
  );
}

function MonthButton({ label, onPress }: { label: string; onPress: () => void }) {
  return (
    <Pressable onPress={onPress} style={({ pressed }) => [styles.button, pressed && styles.dayCellPressed]}>
      <Text style={styles.buttonText}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  container: {
    borderRadius: 28,
    padding: 18,
    backgroundColor: 'rgba(255, 255, 255, 0.08)',
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.14)',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 14,
  },
  monthLabel: {
    color: colors.text,
    fontWeight: '800',
    fontSize: 14,
    letterSpacing: 0.8,
  },
  controls: {
    flexDirection: 'row',
    gap: 8,
  },
  button: {
    width: 28,
    height: 28,
    borderRadius: 999,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(8, 20, 31, 0.46)',
  },
  buttonText: {
    color: colors.text,
    fontWeight: '700',
  },
  weekHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 10,
  },
  weekLabel: {
    width: '14.28%',
    textAlign: 'center',
    color: colors.textMuted,
    fontSize: 12,
    fontWeight: '700',
  },
  grid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
  },
  dayCell: {
    width: '14.28%',
    aspectRatio: 1,
    alignItems: 'center',
    justifyContent: 'center',
    borderRadius: 999,
  },
  dayCellActive: {
    backgroundColor: 'rgba(255, 255, 255, 0.14)',
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.28)',
  },
  dayCellPressed: {
    opacity: 0.78,
  },
  dayText: {
    color: colors.text,
    fontWeight: '700',
    fontSize: 14,
  },
  dayTextMuted: {
    color: 'rgba(237, 246, 251, 0.36)',
  },
  dayTextActive: {
    color: colors.text,
  },
});
