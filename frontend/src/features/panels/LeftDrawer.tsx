import { ReactNode, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';

import { DailyState } from '../daily-state/domain';
import { MonthCalendar } from './MonthCalendar';
import { colors } from '../../theme/tokens';
import { confirmAction } from '../../utils/confirm';

type LeftDrawerProps = {
  selectedDate: string;
  dailyState: DailyState;
  isOpen: boolean;
  width: number;
  topOffset: number;
  onOpen: () => void;
  onClose: () => void;
  onSelectDate: (dateKey: string) => void;
  onSetNotes: (notes: string) => void;
  onCopyYesterday: () => void;
  onCopyDay: (targetDate: string) => void;
  onApplyWeek: (includeWeekend: boolean) => void;
};

export function LeftDrawer({
  selectedDate,
  dailyState,
  isOpen,
  width,
  topOffset,
  onOpen,
  onClose,
  onSelectDate,
  onSetNotes,
  onCopyYesterday,
  onCopyDay,
  onApplyWeek,
}: LeftDrawerProps) {
  const [copyTarget, setCopyTarget] = useState(selectedDate);

  const handleCopyYesterday = async () => {
    const confirmed = await confirmAction(
      'Copiar ayer',
      'Se sobrescribira la configuracion actual con la del dia anterior.',
    );

    if (confirmed) {
      onCopyYesterday();
    }
  };

  const handleCopyDay = async () => {
    const confirmed = await confirmAction(
      'Copiar dia',
      `Se sobrescribira ${copyTarget} con la configuracion de ${selectedDate}.`,
    );

    if (confirmed) {
      onCopyDay(copyTarget);
    }
  };

  const handleApplyWeek = async (includeWeekend: boolean) => {
    const confirmed = await confirmAction(
      includeWeekend ? 'Aplicar 7 dias' : 'Aplicar lunes-viernes',
      'Los dias destino se sobrescribiran con la configuracion del dia actual.',
    );

    if (confirmed) {
      onApplyWeek(includeWeekend);
    }
  };

  return (
    <>
      {isOpen ? (
        <View style={[styles.drawer, { width, top: topOffset, left: 16 }]}>
          <View style={styles.drawerHeader}>
            <Text style={styles.drawerTitle}>Agenda</Text>
            <Pressable onPress={onClose} style={({ pressed }) => [styles.iconButton, pressed && styles.pressed]}>
              <Text style={styles.iconButtonText}>×</Text>
            </Pressable>
          </View>

          <ScrollView contentContainerStyle={styles.content}>
            <MonthCalendar selectedDate={selectedDate} onSelectDate={onSelectDate} />

            <PanelBlock title="Notas">
              <TextInput
                multiline
                value={dailyState.notes}
                onChangeText={onSetNotes}
                placeholder="Notas compartidas del dia..."
                placeholderTextColor={colors.textMuted}
                style={styles.notesInput}
                textAlignVertical="top"
              />
            </PanelBlock>

            <PanelBlock title="Acciones">
              <View style={styles.actionGrid}>
                <ActionButton label="Copiar ayer" onPress={handleCopyYesterday} />
                <ActionButton label="Lun-vie" onPress={() => handleApplyWeek(false)} />
                <ActionButton label="7 dias" onPress={() => handleApplyWeek(true)} />
              </View>

              <View style={styles.copyRow}>
                <TextInput
                  value={copyTarget}
                  onChangeText={setCopyTarget}
                  placeholder="YYYY-MM-DD"
                  placeholderTextColor={colors.textMuted}
                  style={styles.copyInput}
                />
                <ActionButton label="Copiar dia" onPress={handleCopyDay} />
              </View>
            </PanelBlock>
          </ScrollView>
        </View>
      ) : (
        <EdgeButton side="left" label="Agenda" onPress={onOpen} topOffset={topOffset + 64} />
      )}
    </>
  );
}

function PanelBlock({ title, children }: { title: string; children: ReactNode }) {
  return (
    <View style={styles.block}>
      <Text style={styles.blockTitle}>{title}</Text>
      {children}
    </View>
  );
}

function ActionButton({ label, onPress }: { label: string; onPress: () => void }) {
  return (
    <Pressable onPress={onPress} style={({ pressed }) => [styles.actionButton, pressed && styles.pressed]}>
      <Text style={styles.actionText}>{label}</Text>
    </Pressable>
  );
}

export function EdgeButton({
  side,
  label,
  onPress,
  topOffset,
}: {
  side: 'left' | 'right';
  label: string;
  onPress: () => void;
  topOffset: number;
}) {
  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [
        styles.edgeButton,
        side === 'left' ? styles.edgeLeft : styles.edgeRight,
        { top: topOffset },
        pressed && styles.pressed,
      ]}
    >
      <Text style={styles.edgeText}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  drawer: {
    position: 'absolute',
    bottom: 16,
    borderRadius: 26,
    backgroundColor: 'rgba(9, 20, 30, 0.92)',
    borderWidth: 1,
    borderColor: 'rgba(151, 181, 200, 0.18)',
    overflow: 'hidden',
  },
  drawerHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 18,
    paddingTop: 16,
    paddingBottom: 10,
  },
  drawerTitle: {
    color: colors.text,
    fontSize: 18,
    fontWeight: '800',
  },
  iconButton: {
    width: 32,
    height: 32,
    borderRadius: 999,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(255, 255, 255, 0.08)',
  },
  iconButtonText: {
    color: colors.text,
    fontSize: 22,
    lineHeight: 22,
  },
  content: {
    paddingHorizontal: 18,
    paddingBottom: 18,
    gap: 18,
  },
  block: {
    gap: 10,
  },
  blockTitle: {
    color: colors.text,
    fontWeight: '700',
    fontSize: 15,
  },
  notesInput: {
    minHeight: 132,
    paddingHorizontal: 14,
    paddingVertical: 14,
    borderRadius: 18,
    borderWidth: 1,
    borderColor: 'rgba(151, 181, 200, 0.16)',
    backgroundColor: 'rgba(255, 255, 255, 0.04)',
    color: colors.text,
  },
  actionGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
  },
  actionButton: {
    paddingHorizontal: 14,
    paddingVertical: 11,
    borderRadius: 14,
    backgroundColor: 'rgba(16, 34, 50, 0.9)',
    borderWidth: 1,
    borderColor: 'rgba(56, 189, 248, 0.14)',
  },
  actionText: {
    color: colors.text,
    fontWeight: '700',
  },
  copyRow: {
    flexDirection: 'row',
    gap: 10,
    alignItems: 'center',
    flexWrap: 'wrap',
  },
  copyInput: {
    flex: 1,
    minWidth: 140,
    paddingHorizontal: 12,
    paddingVertical: 10,
    borderRadius: 14,
    color: colors.text,
    borderWidth: 1,
    borderColor: 'rgba(151, 181, 200, 0.16)',
    backgroundColor: 'rgba(255, 255, 255, 0.04)',
  },
  edgeButton: {
    position: 'absolute',
    paddingHorizontal: 12,
    paddingVertical: 14,
    borderRadius: 14,
    backgroundColor: 'rgba(9, 20, 30, 0.92)',
    borderWidth: 1,
    borderColor: 'rgba(151, 181, 200, 0.18)',
  },
  edgeLeft: {
    left: 16,
  },
  edgeRight: {
    right: 16,
  },
  edgeText: {
    color: colors.text,
    fontWeight: '700',
  },
  pressed: {
    opacity: 0.82,
  },
});
