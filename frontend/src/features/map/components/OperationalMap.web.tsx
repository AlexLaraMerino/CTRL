import { useEffect, useMemo, useRef, useState } from 'react';
import { PanResponder, Pressable, StyleSheet, Text, View } from 'react-native';

import { DailyState, EmployeeRecord, WorkSite } from '../../daily-state/domain';
import { buildMapPresentation, MapEmployeeMarker } from '../mapViewModel';
import { colors } from '../../../theme/tokens';
import { canvasToGeo, geoToCanvas } from '../../../utils/geo';

type OperationalMapProps = {
  dailyState: DailyState;
  employees: EmployeeRecord[];
  workSites: WorkSite[];
  relocatingEmployeeId?: string | null;
  relocationPoint?: { pageX: number; pageY: number } | null;
  relocationDropPoint?: { pageX: number; pageY: number } | null;
  onMoveEmployee: (employeeId: string, latitude: number, longitude: number) => void;
  onStartRelocation?: (employeeId: string, point: { pageX: number; pageY: number }, source: 'panel' | 'map') => void;
  onMoveRelocation?: (point: { pageX: number; pageY: number }) => void;
  onDropRelocation?: (point: { pageX: number; pageY: number }) => void;
  onPlaceRelocatingEmployee?: (employeeId: string, latitude: number, longitude: number) => void;
};

export function OperationalMap({
  dailyState,
  employees,
  workSites,
  relocatingEmployeeId,
  relocationPoint,
  relocationDropPoint,
  onMoveEmployee,
  onStartRelocation,
  onMoveRelocation,
  onDropRelocation,
  onPlaceRelocatingEmployee,
}: OperationalMapProps) {
  const [layout, setLayout] = useState({ x: 0, y: 0, width: 1, height: 1 });
  const [activeEmployeeId, setActiveEmployeeId] = useState<string | null>(null);
  const [ghostPoint, setGhostPoint] = useState({ x: 48, y: 48 });
  const [showRelocationGhost, setShowRelocationGhost] = useState(false);
  const presentation = useMemo(
    () => buildMapPresentation(dailyState, employees, workSites, relocatingEmployeeId),
    [dailyState, employees, relocatingEmployeeId, workSites],
  );
  const activeEmployeeName = employees.find((employee) => employee.id === activeEmployeeId)?.name;
  const relocatingEmployee = employees.find((employee) => employee.id === relocatingEmployeeId);

  useEffect(() => {
    if (!relocatingEmployeeId) {
      setShowRelocationGhost(false);
      return;
    }

    if (relocationPoint) {
      updateGhost(relocationPoint.pageX, relocationPoint.pageY);
      setShowRelocationGhost(true);
      return;
    }

    const placement = dailyState.employeePlacements[relocatingEmployeeId];

    if (!placement) {
      setGhostPoint({ x: layout.width / 2, y: layout.height / 2 });
      setShowRelocationGhost(true);
      return;
    }

    const point = geoToCanvas(placement, layout.width, layout.height);
    setGhostPoint({
      x: Math.max(0, Math.min(layout.width, point.x)),
      y: Math.max(0, Math.min(layout.height, point.y)),
    });
    setShowRelocationGhost(true);
  }, [dailyState.employeePlacements, layout.height, layout.width, relocatingEmployeeId, relocationPoint]);

  useEffect(() => {
    if (!relocatingEmployeeId || !relocationDropPoint || !onPlaceRelocatingEmployee) {
      return;
    }

    const x = Math.max(0, Math.min(layout.width, relocationDropPoint.pageX - layout.x));
    const y = Math.max(0, Math.min(layout.height, relocationDropPoint.pageY - layout.y));
    const coordinates = canvasToGeo(x, y, layout.width, layout.height);

    onPlaceRelocatingEmployee(relocatingEmployeeId, coordinates.lat, coordinates.lng);
  }, [layout.height, layout.width, layout.x, layout.y, onPlaceRelocatingEmployee, relocatingEmployeeId, relocationDropPoint]);

  const relocationResponder = useMemo(
    () =>
      PanResponder.create({
        onStartShouldSetPanResponder: () => Boolean(relocatingEmployeeId),
        onMoveShouldSetPanResponder: () => Boolean(relocatingEmployeeId),
        onPanResponderGrant: (event) => {
          updateGhost(event.nativeEvent.pageX, event.nativeEvent.pageY);
          onMoveRelocation?.({
            pageX: event.nativeEvent.pageX,
            pageY: event.nativeEvent.pageY,
          });
        },
        onPanResponderMove: (event) => {
          updateGhost(event.nativeEvent.pageX, event.nativeEvent.pageY);
          onMoveRelocation?.({
            pageX: event.nativeEvent.pageX,
            pageY: event.nativeEvent.pageY,
          });
        },
        onPanResponderRelease: (event) => {
          if (!relocatingEmployeeId || !onPlaceRelocatingEmployee) {
            return;
          }

          onDropRelocation?.({
            pageX: event.nativeEvent.pageX,
            pageY: event.nativeEvent.pageY,
          });

          const x = Math.max(0, Math.min(layout.width, event.nativeEvent.pageX - layout.x));
          const y = Math.max(0, Math.min(layout.height, event.nativeEvent.pageY - layout.y));
          const coordinates = canvasToGeo(x, y, layout.width, layout.height);

          onPlaceRelocatingEmployee(relocatingEmployeeId, coordinates.lat, coordinates.lng);
        },
        onPanResponderTerminate: () => {
          setShowRelocationGhost(false);
        },
      }),
    [layout.height, layout.width, layout.x, layout.y, onDropRelocation, onMoveRelocation, onPlaceRelocatingEmployee, relocatingEmployeeId],
  );

  function updateGhost(pageX: number, pageY: number) {
    setGhostPoint({
      x: Math.max(0, Math.min(layout.width, pageX - layout.x)),
      y: Math.max(0, Math.min(layout.height, pageY - layout.y)),
    });
  }

  return (
    <View
      style={styles.container}
      onLayout={(event) => {
        const { x, y, width, height } = event.nativeEvent.layout;
        setLayout({ x, y, width, height });
      }}
    >
      <View style={styles.mapSurface}>
        <View style={styles.grid} />
        <View style={styles.glowOne} />
        <View style={styles.glowTwo} />

        {presentation.workSiteMarkers.map((workSite) => {
          const point = geoToCanvas(workSite, layout.width, layout.height);

          return (
            <View
              key={workSite.id}
              style={[
                styles.workMarker,
                {
                  left: point.x - 38,
                  top: point.y - 18,
                },
              ]}
            >
              <Text style={styles.workMarkerText}>{workSite.city}</Text>
              {workSite.assignedCount ? (
                <Text style={styles.workMarkerCount}>x{workSite.assignedCount}</Text>
              ) : null}
            </View>
          );
        })}

        {presentation.employeeGroups.map((group) => {
          const point = geoToCanvas(group, layout.width, layout.height);

          return (
            <View
              key={group.id}
              style={[
                styles.groupMarker,
                {
                  left: point.x - 22,
                  top: point.y - 22,
                },
              ]}
            >
              <Text style={styles.groupMarkerText}>x{group.count}</Text>
            </View>
          );
        })}

        {presentation.employeeMarkers.map((marker) => {
          const employee = employees.find((item) => item.id === marker.employeeId);

          if (!employee) {
            return null;
          }

          return (
            <EmployeeMarker
              key={marker.employeeId}
              employee={employee}
              marker={marker}
              width={layout.width}
              height={layout.height}
              active={activeEmployeeId === marker.employeeId}
              onMoveEmployee={onMoveEmployee}
              onDragStateChange={setActiveEmployeeId}
              onStartRelocation={onStartRelocation}
              onMoveRelocation={onMoveRelocation}
              onDropRelocation={onDropRelocation}
            />
          );
        })}
      </View>

      {relocatingEmployee ? (
        <View style={StyleSheet.absoluteFill} {...relocationResponder.panHandlers}>
          {showRelocationGhost ? (
            <View
              style={[
                styles.relocatingGhost,
                { left: ghostPoint.x - 26, top: ghostPoint.y - 26, borderColor: relocatingEmployee.color },
              ]}
            >
              <Text style={styles.relocatingGhostText}>
                {relocatingEmployee.name.slice(0, 2).toUpperCase()}
              </Text>
            </View>
          ) : null}
        </View>
      ) : null}

      {activeEmployeeName ? (
        <View style={styles.dragOverlay}>
          <Text style={styles.dragTitle}>Moviendo</Text>
          <Text style={styles.dragValue}>{activeEmployeeName}</Text>
        </View>
      ) : null}

      <View style={styles.bottomStats}>
        <MapStat label="Obras" value={String(presentation.workSiteMarkers.length)} />
        <MapStat label="Operarios" value={String(presentation.employeeMarkers.length)} />
      </View>
    </View>
  );
}

function EmployeeMarker({
  employee,
  marker,
  width,
  height,
  active,
  onMoveEmployee,
  onDragStateChange,
  onStartRelocation,
  onMoveRelocation,
  onDropRelocation,
}: {
  employee: EmployeeRecord;
  marker: MapEmployeeMarker;
  width: number;
  height: number;
  active: boolean;
  onMoveEmployee: (employeeId: string, latitude: number, longitude: number) => void;
  onDragStateChange: (employeeId: string | null) => void;
  onStartRelocation?: (employeeId: string, point: { pageX: number; pageY: number }, source: 'panel' | 'map') => void;
  onMoveRelocation?: (point: { pageX: number; pageY: number }) => void;
  onDropRelocation?: (point: { pageX: number; pageY: number }) => void;
}) {
  const point = geoToCanvas(marker, width, height);
  const relocationTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const relocationActiveRef = useRef(false);

  const responder = useMemo(
    () =>
      PanResponder.create({
        onStartShouldSetPanResponder: () => true,
        onMoveShouldSetPanResponder: () => true,
        onPanResponderGrant: () => onDragStateChange(employee.id),
        onPanResponderMove: (_, gestureState) => {
          const nextX = Math.max(18, Math.min(width - 18, point.x + gestureState.dx));
          const nextY = Math.max(18, Math.min(height - 18, point.y + gestureState.dy));
          const coordinates = canvasToGeo(nextX, nextY, width, height);

          onMoveEmployee(employee.id, coordinates.lat, coordinates.lng);
        },
        onPanResponderRelease: () => onDragStateChange(null),
        onPanResponderTerminate: () => onDragStateChange(null),
      }),
    [employee.id, height, onDragStateChange, onMoveEmployee, point.x, point.y, width],
  );

  const clearRelocationTimer = () => {
    if (relocationTimerRef.current) {
      clearTimeout(relocationTimerRef.current);
      relocationTimerRef.current = null;
    }
  };

  return (
    <Pressable
      onPressIn={(event) => {
        relocationActiveRef.current = false;
        clearRelocationTimer();
        const point = {
          pageX: event.nativeEvent.pageX,
          pageY: event.nativeEvent.pageY,
        };

        relocationTimerRef.current = setTimeout(() => {
          relocationActiveRef.current = true;
          onDragStateChange(employee.id);
          onStartRelocation?.(employee.id, point, 'map');
        }, 650);
      }}
      onTouchMove={(event) => {
        if (!relocationActiveRef.current) {
          return;
        }

        onMoveRelocation?.({
          pageX: event.nativeEvent.pageX,
          pageY: event.nativeEvent.pageY,
        });
      }}
      onPressOut={(event) => {
        clearRelocationTimer();

        if (!relocationActiveRef.current) {
          onDragStateChange(null);
          return;
        }

        onDropRelocation?.({
          pageX: event.nativeEvent.pageX,
          pageY: event.nativeEvent.pageY,
        });
        onDragStateChange(null);
        relocationActiveRef.current = false;
      }}
      style={[
        styles.employeeMarker,
        {
          left: point.x - (marker.compact ? 10 : 20),
          top: point.y - (marker.compact ? 10 : 20),
          borderColor: employee.color,
        },
        marker.compact && styles.employeeMarkerCompact,
        active && styles.employeeMarkerActive,
      ]}
    >
      <View {...responder.panHandlers} style={StyleSheet.absoluteFill} />
      {!marker.compact ? (
        <Text style={styles.employeeMarkerText}>{employee.name.slice(0, 2).toUpperCase()}</Text>
      ) : null}
    </Pressable>
  );
}

function MapStat({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.statCard}>
      <Text style={styles.statValue}>{value}</Text>
      <Text style={styles.statLabel}>{label}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    borderRadius: 28,
    overflow: 'hidden',
    borderWidth: 1,
    borderColor: colors.line,
    backgroundColor: '#07111a',
    position: 'relative',
  },
  mapSurface: {
    flex: 1,
    backgroundColor: '#07111a',
  },
  grid: {
    ...StyleSheet.absoluteFillObject,
    opacity: 0.2,
    backgroundColor: '#0d2231',
  },
  glowOne: {
    position: 'absolute',
    width: 320,
    height: 320,
    borderRadius: 999,
    backgroundColor: 'rgba(56, 189, 248, 0.12)',
    left: 120,
    top: 40,
  },
  glowTwo: {
    position: 'absolute',
    width: 260,
    height: 260,
    borderRadius: 999,
    backgroundColor: 'rgba(249, 115, 22, 0.12)',
    right: 120,
    bottom: 50,
  },
  workMarker: {
    position: 'absolute',
    minWidth: 76,
    paddingHorizontal: 10,
    paddingVertical: 8,
    borderRadius: 14,
    backgroundColor: colors.work,
    alignItems: 'center',
  },
  workMarkerText: {
    color: '#08141f',
    fontWeight: '900',
    fontSize: 12,
  },
  workMarkerCount: {
    color: '#08141f',
    fontWeight: '900',
    fontSize: 11,
    marginTop: 2,
  },
  groupMarker: {
    position: 'absolute',
    width: 44,
    height: 44,
    borderRadius: 999,
    borderWidth: 3,
    borderColor: colors.employee,
    backgroundColor: '#08141f',
    alignItems: 'center',
    justifyContent: 'center',
  },
  groupMarkerText: {
    color: colors.text,
    fontWeight: '900',
    fontSize: 12,
  },
  employeeMarker: {
    position: 'absolute',
    width: 40,
    height: 40,
    borderRadius: 999,
    borderWidth: 3,
    backgroundColor: '#08141f',
    alignItems: 'center',
    justifyContent: 'center',
  },
  employeeMarkerCompact: {
    width: 20,
    height: 20,
    borderWidth: 2,
  },
  employeeMarkerActive: {
    backgroundColor: colors.accentSoft,
  },
  employeeMarkerText: {
    color: colors.text,
    fontWeight: '900',
    fontSize: 12,
  },
  relocatingGhost: {
    position: 'absolute',
    width: 52,
    height: 52,
    borderRadius: 999,
    borderWidth: 3,
    backgroundColor: 'rgba(8, 20, 31, 0.94)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  relocatingGhostText: {
    color: colors.text,
    fontWeight: '900',
    fontSize: 14,
  },
  dragOverlay: {
    position: 'absolute',
    left: 16,
    bottom: 16,
    paddingHorizontal: 14,
    paddingVertical: 12,
    borderRadius: 16,
    backgroundColor: 'rgba(8, 20, 31, 0.92)',
  },
  dragTitle: {
    color: colors.textMuted,
    fontSize: 12,
    textTransform: 'uppercase',
    letterSpacing: 0.8,
  },
  dragValue: {
    color: colors.text,
    fontWeight: '800',
    marginTop: 4,
  },
  bottomStats: {
    position: 'absolute',
    right: 16,
    bottom: 16,
    flexDirection: 'row',
    gap: 10,
  },
  statCard: {
    paddingHorizontal: 12,
    paddingVertical: 10,
    borderRadius: 14,
    backgroundColor: 'rgba(8, 20, 31, 0.9)',
    minWidth: 84,
  },
  statValue: {
    color: colors.text,
    fontSize: 18,
    fontWeight: '800',
  },
  statLabel: {
    color: colors.textMuted,
    fontSize: 11,
    marginTop: 2,
  },
});
