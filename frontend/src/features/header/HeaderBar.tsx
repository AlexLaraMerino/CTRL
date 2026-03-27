import { useEffect, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';

import { addDays, formatDateFull, getSpainDateKey } from '../daily-state/date';
import { colors } from '../../theme/tokens';

type HeaderBarProps = {
  selectedDate: string;
  onSelectDate: (dateKey: string) => void;
  onOpenLeftPanel: () => void;
  onOpenEmployeesPanel: () => void;
  onOpenWorkSitesPanel: () => void;
};

function getSpainTimeLabel() {
  return new Intl.DateTimeFormat('es-ES', {
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false,
    timeZone: 'Europe/Madrid',
  }).format(new Date());
}

export function HeaderBar({
  selectedDate,
  onSelectDate,
  onOpenLeftPanel,
  onOpenEmployeesPanel,
  onOpenWorkSitesPanel,
}: HeaderBarProps) {
  const [now, setNow] = useState(getSpainTimeLabel());

  useEffect(() => {
    const timer = setInterval(() => setNow(getSpainTimeLabel()), 1000);

    return () => clearInterval(timer);
  }, []);

  return (
    <View style={styles.container}>
      <View style={styles.leftSection}>
        <HeaderButton label="Agenda" onPress={onOpenLeftPanel} />
        <Text style={styles.dateText} numberOfLines={1}>
          {formatDateFull(selectedDate)}
        </Text>
      </View>

      <View style={styles.rightSection}>
        <Text style={styles.time}>ES {now}</Text>
        <HeaderButton label="-1" onPress={() => onSelectDate(addDays(selectedDate, -1))} />
        <HeaderButton label="Hoy" onPress={() => onSelectDate(getSpainDateKey())} />
        <HeaderButton label="+1" onPress={() => onSelectDate(addDays(selectedDate, 1))} />
        <HeaderButton label="Operarios" onPress={onOpenEmployeesPanel} />
        <HeaderButton label="Obras" onPress={onOpenWorkSitesPanel} />
      </View>
    </View>
  );
}

function HeaderButton({ label, onPress }: { label: string; onPress: () => void }) {
  return (
    <Pressable onPress={onPress} style={({ pressed }) => [styles.button, pressed && styles.pressed]}>
      <Text style={styles.buttonText}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: 12,
    paddingHorizontal: 14,
    paddingVertical: 10,
    borderRadius: 18,
    borderWidth: 1,
    borderColor: 'rgba(151, 181, 200, 0.18)',
    backgroundColor: 'rgba(8, 20, 31, 0.82)',
  },
  leftSection: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    flex: 1,
    minWidth: 0,
  },
  rightSection: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    flexWrap: 'wrap',
    justifyContent: 'flex-end',
  },
  dateText: {
    color: colors.text,
    fontSize: 17,
    fontWeight: '700',
    textTransform: 'capitalize',
    flexShrink: 1,
  },
  time: {
    color: colors.textMuted,
    fontSize: 13,
    fontWeight: '700',
    marginRight: 4,
  },
  button: {
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 12,
    backgroundColor: 'rgba(16, 34, 50, 0.92)',
    borderWidth: 1,
    borderColor: 'rgba(56, 189, 248, 0.18)',
  },
  buttonText: {
    color: colors.text,
    fontWeight: '700',
    fontSize: 13,
  },
  pressed: {
    opacity: 0.82,
  },
});
