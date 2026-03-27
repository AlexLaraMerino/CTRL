import { useMemo, useRef, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';

import { DailyState, EmployeeRecord } from '../daily-state/domain';
import { isEmployeeAbsent } from '../daily-state/helpers';
import { colors } from '../../theme/tokens';
import { confirmAction } from '../../utils/confirm';
import { EdgeButton } from './LeftDrawer';

type EmployeesDrawerProps = {
  employees: EmployeeRecord[];
  dailyState: DailyState;
  isOpen: boolean;
  hidden?: boolean;
  relocating?: boolean;
  width: number;
  topOffset: number;
  onOpen: () => void;
  onClose: () => void;
  onAddEmployee: (name: string) => void;
  onUpdateEmployee: (employeeId: string, name: string) => void;
  onSetEmployeeActive: (employeeId: string, active: boolean) => void;
  onToggleAbsence: (employeeId: string) => void;
  onStartRelocation: (employeeId: string, point: { pageX: number; pageY: number }, source: 'panel' | 'map') => void;
  onMoveRelocation: (point: { pageX: number; pageY: number }) => void;
  onDropRelocation: (point: { pageX: number; pageY: number }) => void;
};

export function EmployeesDrawer({
  employees,
  dailyState,
  isOpen,
  hidden,
  relocating,
  width,
  topOffset,
  onOpen,
  onClose,
  onAddEmployee,
  onUpdateEmployee,
  onSetEmployeeActive,
  onToggleAbsence,
  onStartRelocation,
  onMoveRelocation,
  onDropRelocation,
}: EmployeesDrawerProps) {
  const [drafts, setDrafts] = useState<Record<string, string>>({});
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [inactiveOpen, setInactiveOpen] = useState(false);
  const [newName, setNewName] = useState('');
  const relocationTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const relocationActiveRef = useRef(false);
  const suppressPressRef = useRef(false);

  const rows = useMemo(
    () =>
      employees.map((employee) => ({
        ...employee,
        draft: drafts[employee.id] ?? employee.name,
        absent: isEmployeeAbsent(dailyState, employee.id),
      })),
    [dailyState, drafts, employees],
  );

  const activeRows = rows.filter((employee) => employee.active);
  const inactiveRows = rows.filter((employee) => !employee.active);

  const handleDeactivate = async (employeeId: string, name: string) => {
    const confirmed = await confirmAction(
      'Desactivar operario',
      `${name} pasara a operarios inactivos y saldra del mapa.`,
    );

    if (confirmed) {
      onSetEmployeeActive(employeeId, false);
    }
  };

  const handleCreate = () => {
    const trimmed = newName.trim();

    if (!trimmed) {
      return;
    }

    onAddEmployee(trimmed);
    setNewName('');
  };

  const clearRelocationTimer = () => {
    if (relocationTimerRef.current) {
      clearTimeout(relocationTimerRef.current);
      relocationTimerRef.current = null;
    }
  };

  const beginRowPress = (employeeId: string, point: { pageX: number; pageY: number }) => {
    relocationActiveRef.current = false;
    suppressPressRef.current = false;
    clearRelocationTimer();
    relocationTimerRef.current = setTimeout(() => {
      relocationActiveRef.current = true;
      suppressPressRef.current = true;
      setExpandedId(null);
      onStartRelocation(employeeId, point, 'panel');
    }, 650);
  };

  const moveRowPress = (point: { pageX: number; pageY: number }) => {
    if (relocationActiveRef.current) {
      onMoveRelocation(point);
    }
  };

  const endRowPress = (point: { pageX: number; pageY: number }) => {
    clearRelocationTimer();

    if (relocationActiveRef.current) {
      onDropRelocation(point);
      relocationActiveRef.current = false;
      setTimeout(() => {
        suppressPressRef.current = false;
      }, 0);
    }
  };

  return (
    <>
      {isOpen ? (
        <View
          pointerEvents={relocating ? 'none' : 'auto'}
          style={[
            styles.drawer,
            { width, top: topOffset, right: 16 },
            relocating && styles.drawerRelocating,
          ]}
        >
          <View style={styles.drawerHeader}>
            <Text style={styles.drawerTitle}>Operarios</Text>
            <Pressable onPress={onClose} style={({ pressed }) => [styles.iconButton, pressed && styles.pressed]}>
              <Text style={styles.iconButtonText}>×</Text>
            </Pressable>
          </View>

          <ScrollView contentContainerStyle={styles.content}>
            {activeRows.map((employee) => {
              const expanded = expandedId === employee.id;

              return (
                <View key={employee.id} style={styles.rowCard}>
                  <Pressable
                    onPress={() => {
                      if (suppressPressRef.current) {
                        return;
                      }

                      setExpandedId(expanded ? null : employee.id);
                    }}
                    onPressIn={(event) =>
                      beginRowPress(employee.id, {
                        pageX: event.nativeEvent.pageX,
                        pageY: event.nativeEvent.pageY,
                      })
                    }
                    onPressOut={(event) =>
                      endRowPress({
                        pageX: event.nativeEvent.pageX,
                        pageY: event.nativeEvent.pageY,
                      })
                    }
                    onTouchMove={(event) =>
                      moveRowPress({
                        pageX: event.nativeEvent.pageX,
                        pageY: event.nativeEvent.pageY,
                      })
                    }
                    style={({ pressed }) => [styles.rowMain, pressed && styles.pressed]}
                  >
                    <View style={[styles.dot, { backgroundColor: employee.color }]} />
                    <View style={styles.rowCopy}>
                      <Text style={styles.rowName}>{employee.draft}</Text>
                      <Text style={styles.rowMeta}>
                        {employee.absent
                          ? '✕ Ausente en este dia'
                          : 'Pulsa para acciones. Mantener para recolocar'}
                      </Text>
                    </View>
                    <Text style={styles.chevron}>{expanded ? '−' : '+'}</Text>
                  </Pressable>

                  {expanded ? (
                    <View style={styles.expandedArea}>
                      <TextInput
                        value={employee.draft}
                        onChangeText={(value) =>
                          setDrafts((current) => ({
                            ...current,
                            [employee.id]: value,
                          }))
                        }
                        placeholder="Nombre"
                        placeholderTextColor={colors.textMuted}
                        style={styles.input}
                      />

                      <View style={styles.actionGrid}>
                        <LabeledAction
                          icon="✎"
                          title="Editar"
                          description="Guardar nombre"
                          onPress={() => onUpdateEmployee(employee.id, employee.draft.trim() || employee.name)}
                        />
                        <LabeledAction
                          icon="⛔"
                          title="Desactivar"
                          description="Mover a inactivos"
                          onPress={() => handleDeactivate(employee.id, employee.name)}
                        />
                        <LabeledAction
                          icon="✕"
                          title={employee.absent ? 'Activar' : 'Ausencia'}
                          description={
                            employee.absent
                              ? 'Volver a mostrarlo hoy'
                              : 'Ocultarlo del mapa hoy'
                          }
                          onPress={() => onToggleAbsence(employee.id)}
                        />
                      </View>

                      <Text style={styles.dragHint}>
                        Mantener pulsado para sacarlo del mapa y recolocarlo.
                      </Text>
                    </View>
                  ) : null}
                </View>
              );
            })}

            <View style={styles.createCard}>
              <Text style={styles.createTitle}>Nuevo operario</Text>
              <View style={styles.createRow}>
                <TextInput
                  value={newName}
                  onChangeText={setNewName}
                  placeholder="Nombre del operario"
                  placeholderTextColor={colors.textMuted}
                  style={styles.input}
                />
                <MiniAction label="＋" onPress={handleCreate} />
              </View>
            </View>

            <View style={styles.inactiveWrap}>
              <Pressable
                onPress={() => setInactiveOpen((current) => !current)}
                style={({ pressed }) => [styles.inactiveHeader, pressed && styles.pressed]}
              >
                <Text style={styles.createTitle}>Operarios inactivos</Text>
                <Text style={styles.inactiveCount}>{inactiveOpen ? '−' : '+'}</Text>
              </Pressable>

              {inactiveOpen ? (
                <View style={styles.inactiveList}>
                  {inactiveRows.length === 0 ? (
                    <Text style={styles.emptyText}>No hay operarios inactivos.</Text>
                  ) : (
                    inactiveRows.map((employee) => {
                      const expanded = expandedId === employee.id;

                      return (
                        <View key={employee.id} style={styles.rowCard}>
                          <Pressable
                            onPress={() => setExpandedId(expanded ? null : employee.id)}
                            style={({ pressed }) => [styles.rowMain, pressed && styles.pressed]}
                          >
                            <View style={[styles.dot, { backgroundColor: employee.color }]} />
                            <View style={styles.rowCopy}>
                              <Text style={styles.rowName}>{employee.draft}</Text>
                              <Text style={styles.rowMeta}>Operario inactivo</Text>
                            </View>
                            <Text style={styles.chevron}>{expanded ? '−' : '+'}</Text>
                          </Pressable>

                          {expanded ? (
                            <View style={styles.expandedArea}>
                              <LabeledAction
                                icon="↺"
                                title="Activar"
                                description="Devolver a operarios activos"
                                onPress={() => onSetEmployeeActive(employee.id, true)}
                              />
                            </View>
                          ) : null}
                        </View>
                      );
                    })
                  )}
                </View>
              ) : null}
            </View>
          </ScrollView>
        </View>
      ) : hidden ? null : (
        <EdgeButton side="right" label="Operarios" onPress={onOpen} topOffset={topOffset + 64} />
      )}
    </>
  );
}

function LabeledAction({
  icon,
  title,
  description,
  onPress,
}: {
  icon: string;
  title: string;
  description: string;
  onPress: () => void;
}) {
  return (
    <Pressable onPress={onPress} style={({ pressed }) => [styles.labeledAction, pressed && styles.pressed]}>
      <View style={styles.actionIconWrap}>
        <Text style={styles.actionIcon}>{icon}</Text>
      </View>
      <Text style={styles.actionTitle}>{title}</Text>
      <Text style={styles.actionDescription}>{description}</Text>
    </Pressable>
  );
}

function MiniAction({ label, onPress }: { label: string; onPress: () => void }) {
  return (
    <Pressable onPress={onPress} style={({ pressed }) => [styles.actionButton, pressed && styles.pressed]}>
      <Text style={styles.actionText}>{label}</Text>
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
  drawerRelocating: {
    opacity: 0.02,
    transform: [{ translateX: 420 }],
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
    gap: 12,
  },
  rowCard: {
    padding: 12,
    borderRadius: 18,
    backgroundColor: 'rgba(255, 255, 255, 0.04)',
    gap: 10,
  },
  rowMain: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
  },
  dot: {
    width: 12,
    height: 12,
    borderRadius: 999,
  },
  rowCopy: {
    flex: 1,
  },
  rowName: {
    color: colors.text,
    fontWeight: '700',
  },
  rowMeta: {
    color: colors.textMuted,
    marginTop: 2,
    fontSize: 12,
  },
  chevron: {
    color: colors.text,
    fontSize: 22,
    fontWeight: '700',
  },
  expandedArea: {
    gap: 10,
  },
  input: {
    flex: 1,
    minWidth: 0,
    paddingHorizontal: 12,
    paddingVertical: 10,
    borderRadius: 14,
    color: colors.text,
    borderWidth: 1,
    borderColor: 'rgba(151, 181, 200, 0.16)',
    backgroundColor: 'rgba(255, 255, 255, 0.04)',
  },
  actionGrid: {
    flexDirection: 'row',
    gap: 10,
  },
  labeledAction: {
    flex: 1,
    minHeight: 108,
    padding: 10,
    borderRadius: 14,
    backgroundColor: 'rgba(16, 34, 50, 0.92)',
    borderWidth: 1,
    borderColor: 'rgba(56, 189, 248, 0.12)',
  },
  actionIconWrap: {
    width: 30,
    height: 30,
    borderRadius: 10,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(255, 255, 255, 0.06)',
    marginBottom: 8,
  },
  actionIcon: {
    color: colors.text,
    fontWeight: '700',
  },
  actionTitle: {
    color: colors.text,
    fontWeight: '700',
    fontSize: 11,
    lineHeight: 14,
  },
  actionDescription: {
    color: colors.textMuted,
    fontSize: 11,
    marginTop: 4,
    lineHeight: 15,
  },
  dragHint: {
    color: colors.textMuted,
    fontSize: 12,
  },
  actionButton: {
    width: 36,
    height: 36,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(16, 34, 50, 0.92)',
    borderWidth: 1,
    borderColor: 'rgba(56, 189, 248, 0.12)',
  },
  actionText: {
    color: colors.text,
    fontSize: 15,
    fontWeight: '700',
  },
  createCard: {
    padding: 14,
    borderRadius: 18,
    backgroundColor: 'rgba(255, 255, 255, 0.04)',
    gap: 10,
  },
  createTitle: {
    color: colors.text,
    fontWeight: '700',
  },
  createRow: {
    flexDirection: 'row',
    gap: 10,
    alignItems: 'center',
  },
  inactiveWrap: {
    gap: 10,
  },
  inactiveHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: 14,
    borderRadius: 18,
    backgroundColor: 'rgba(255, 255, 255, 0.04)',
  },
  inactiveCount: {
    color: colors.text,
    fontSize: 20,
    fontWeight: '700',
  },
  inactiveList: {
    gap: 10,
  },
  emptyText: {
    color: colors.textMuted,
    fontSize: 12,
    paddingHorizontal: 4,
  },
  pressed: {
    opacity: 0.82,
  },
});
