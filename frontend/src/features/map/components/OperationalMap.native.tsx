import { useEffect, useMemo, useRef, useState } from 'react';
import { PanResponder, StyleSheet, Text, View } from 'react-native';
import MapView, { Marker } from 'react-native-maps';

import { DailyState, EmployeeRecord, WorkSite } from '../../daily-state/domain';
import { buildMapPresentation, MapEmployeeMarker } from '../mapViewModel';
import { colors } from '../../../theme/tokens';
import { getSpainRegion } from '../../../utils/geo';

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
  const [regionVersion, setRegionVersion] = useState(0);
  const [layout, setLayout] = useState({ x: 0, y: 0, width: 1, height: 1 });
  const [ghostPoint, setGhostPoint] = useState({ x: 0, y: 0 });
  const [showRelocationGhost, setShowRelocationGhost] = useState(false);
  const [employeePoints, setEmployeePoints] = useState<Record<string, { x: number; y: number }>>({});
  const mapRef = useRef<MapView | null>(null);
  const presentation = useMemo(
    () => buildMapPresentation(dailyState, employees, workSites, relocatingEmployeeId),
    [dailyState, employees, relocatingEmployeeId, workSites],
  );
  const relocatingEmployee = employees.find((employee) => employee.id === relocatingEmployeeId);

  useEffect(() => {
    let cancelled = false;

    async function syncEmployeePoints() {
      if (!mapRef.current || layout.width <= 1 || layout.height <= 1) {
        return;
      }

      const entries = await Promise.all(
        presentation.employeeMarkers.map(async (marker) => {
          try {
            const point = await mapRef.current?.pointForCoordinate({
              latitude: marker.lat,
              longitude: marker.lng,
            });

            if (!point) {
              return null;
            }

            return [
              marker.employeeId,
              {
                x: Math.max(0, Math.min(layout.width, point.x)),
                y: Math.max(0, Math.min(layout.height, point.y)),
              },
            ] as const;
          } catch {
            return null;
          }
        }),
      );

      if (cancelled) {
        return;
      }

      setEmployeePoints(
        Object.fromEntries(entries.filter((entry): entry is readonly [string, { x: number; y: number }] => Boolean(entry))),
      );
    }

    syncEmployeePoints();

    return () => {
      cancelled = true;
    };
  }, [layout.height, layout.width, presentation.employeeMarkers, regionVersion]);

  useEffect(() => {
    if (!relocatingEmployeeId) {
      setShowRelocationGhost(false);
      return;
    }

    if (relocationPoint) {
      setGhostPoint(getRelativePoint(relocationPoint.pageX, relocationPoint.pageY));
      setShowRelocationGhost(true);
      return;
    }

    const placement = dailyState.employeePlacements[relocatingEmployeeId];

    if (!placement || !mapRef.current) {
      setGhostPoint({ x: layout.width / 2, y: layout.height / 2 });
      setShowRelocationGhost(true);
      return;
    }

    let cancelled = false;

    mapRef.current
      .pointForCoordinate({
        latitude: placement.lat,
        longitude: placement.lng,
      })
      .then((point) => {
        if (cancelled) {
          return;
        }

        setGhostPoint({
          x: Math.max(0, Math.min(layout.width, point.x)),
          y: Math.max(0, Math.min(layout.height, point.y)),
        });
        setShowRelocationGhost(true);
      })
      .catch(() => {
        if (cancelled) {
          return;
        }

        setGhostPoint({ x: layout.width / 2, y: layout.height / 2 });
        setShowRelocationGhost(true);
      });

    return () => {
      cancelled = true;
    };
  }, [dailyState.employeePlacements, layout.height, layout.width, relocatingEmployeeId, relocationPoint]);

  useEffect(() => {
    if (!relocatingEmployeeId || !relocationDropPoint || !onPlaceRelocatingEmployee || !mapRef.current) {
      return;
    }

    const point = getRelativePoint(relocationDropPoint.pageX, relocationDropPoint.pageY);

    mapRef.current
      .coordinateForPoint(point)
      .then((coordinate) => {
        onPlaceRelocatingEmployee(relocatingEmployeeId, coordinate.latitude, coordinate.longitude);
      })
      .catch(() => undefined);
  }, [onPlaceRelocatingEmployee, relocatingEmployeeId, relocationDropPoint]);

  const relocationResponder = useMemo(
    () =>
      PanResponder.create({
        onStartShouldSetPanResponder: () => Boolean(relocatingEmployeeId),
        onMoveShouldSetPanResponder: () => Boolean(relocatingEmployeeId),
        onPanResponderGrant: (event) => {
          updateGhost(event);
          onMoveRelocation?.({
            pageX: event.nativeEvent.pageX,
            pageY: event.nativeEvent.pageY,
          });
        },
        onPanResponderMove: (event) => {
          updateGhost(event);
          onMoveRelocation?.({
            pageX: event.nativeEvent.pageX,
            pageY: event.nativeEvent.pageY,
          });
        },
        onPanResponderRelease: async (event) => {
          if (!relocatingEmployeeId || !onPlaceRelocatingEmployee || !mapRef.current) {
            return;
          }

          onDropRelocation?.({
            pageX: event.nativeEvent.pageX,
            pageY: event.nativeEvent.pageY,
          });

          const point = getRelativePoint(event.nativeEvent.pageX, event.nativeEvent.pageY);
          const coordinate = await mapRef.current.coordinateForPoint(point);

          onPlaceRelocatingEmployee(relocatingEmployeeId, coordinate.latitude, coordinate.longitude);
        },
        onPanResponderTerminate: () => {
          setShowRelocationGhost(false);
        },
      }),
    [layout.x, layout.y, onDropRelocation, onMoveRelocation, onPlaceRelocatingEmployee, relocatingEmployeeId],
  );

  function getRelativePoint(pageX: number, pageY: number) {
    return {
      x: Math.max(0, Math.min(layout.width, pageX - layout.x)),
      y: Math.max(0, Math.min(layout.height, pageY - layout.y)),
    };
  }

  function updateGhost(event: { nativeEvent: { pageX: number; pageY: number } }) {
    const point = getRelativePoint(event.nativeEvent.pageX, event.nativeEvent.pageY);
    setGhostPoint(point);
  }

  return (
    <View
      style={styles.container}
      onLayout={(event) => {
        const { x, y, width, height } = event.nativeEvent.layout;
        setLayout({ x, y, width, height });
      }}
    >
      <MapView
        ref={mapRef}
        style={styles.map}
        initialRegion={getSpainRegion()}
        onRegionChangeComplete={() => setRegionVersion((current) => current + 1)}
      >
        {presentation.workSiteMarkers.map((workSite) => (
          <Marker
            key={workSite.id}
            coordinate={{ latitude: workSite.lat, longitude: workSite.lng }}
            title={workSite.name}
            description={workSite.city}
          >
            <View style={styles.workMarker}>
              <Text style={styles.workText}>{workSite.city}</Text>
              {workSite.assignedCount ? (
                <View style={styles.countBadge}>
                  <Text style={styles.countText}>x{workSite.assignedCount}</Text>
                </View>
              ) : null}
            </View>
          </Marker>
        ))}

        {presentation.employeeGroups.map((group) => (
          <Marker
            key={group.id}
            coordinate={{ latitude: group.lat, longitude: group.lng }}
            title={`Agrupados x${group.count}`}
            description={group.employeeNames.join(', ')}
          >
            <View style={styles.groupMarker}>
              <Text style={styles.groupCount}>x{group.count}</Text>
            </View>
          </Marker>
        ))}

      </MapView>

      <View pointerEvents="box-none" style={StyleSheet.absoluteFill}>
        {presentation.employeeMarkers.map((marker) => {
          const point = employeePoints[marker.employeeId];

          if (!point) {
            return null;
          }

          return (
            <EmployeeMarker
              key={marker.employeeId}
              marker={marker}
              point={point}
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
      <View style={styles.bottomStats}>
        <MapStat label="Obras" value={String(presentation.workSiteMarkers.length)} />
        <MapStat label="Operarios" value={String(presentation.employeeMarkers.length)} />
      </View>
    </View>
  );
}

function EmployeeMarker({
  marker,
  point,
  onStartRelocation,
  onMoveRelocation,
  onDropRelocation,
}: {
  marker: MapEmployeeMarker;
  point: { x: number; y: number };
  onStartRelocation?: (employeeId: string, point: { pageX: number; pageY: number }, source: 'panel' | 'map') => void;
  onMoveRelocation?: (point: { pageX: number; pageY: number }) => void;
  onDropRelocation?: (point: { pageX: number; pageY: number }) => void;
}) {
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const activeRef = useRef(false);

  const clearTimer = () => {
    if (timerRef.current) {
      clearTimeout(timerRef.current);
      timerRef.current = null;
    }
  };

  return (
    <View
      onTouchStart={(event) => {
        activeRef.current = false;
        clearTimer();
        const point = {
          pageX: event.nativeEvent.pageX,
          pageY: event.nativeEvent.pageY,
        };

        timerRef.current = setTimeout(() => {
          activeRef.current = true;
          onStartRelocation?.(marker.employeeId, point, 'map');
        }, 650);
      }}
      onTouchMove={(event) => {
        if (!activeRef.current) {
          return;
        }

        onMoveRelocation?.({
          pageX: event.nativeEvent.pageX,
          pageY: event.nativeEvent.pageY,
        });
      }}
      onTouchEnd={(event) => {
        clearTimer();

        if (!activeRef.current) {
          return;
        }

        onDropRelocation?.({
          pageX: event.nativeEvent.pageX,
          pageY: event.nativeEvent.pageY,
        });
        activeRef.current = false;
      }}
      style={[
        styles.employeeMarker,
        {
          position: 'absolute',
          left: point.x - (marker.compact ? 10 : 19),
          top: point.y - (marker.compact ? 10 : 19),
        },
        marker.compact && styles.employeeMarkerCompact,
        { borderColor: marker.color },
      ]}
    >
      {!marker.compact ? (
        <Text style={styles.employeeText}>{marker.name.slice(0, 2).toUpperCase()}</Text>
      ) : null}
    </View>
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
  },
  map: {
    flex: 1,
  },
  workMarker: {
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 14,
    backgroundColor: colors.work,
    flexDirection: 'row',
    gap: 8,
    alignItems: 'center',
  },
  workText: {
    color: '#08141f',
    fontWeight: '800',
    fontSize: 12,
  },
  countBadge: {
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 999,
    backgroundColor: '#08141f',
  },
  countText: {
    color: colors.text,
    fontWeight: '800',
    fontSize: 11,
  },
  groupMarker: {
    minWidth: 42,
    height: 42,
    paddingHorizontal: 10,
    borderRadius: 999,
    borderWidth: 3,
    borderColor: colors.employee,
    backgroundColor: '#08141f',
    alignItems: 'center',
    justifyContent: 'center',
  },
  groupCount: {
    color: colors.text,
    fontWeight: '900',
    fontSize: 12,
  },
  employeeMarker: {
    width: 38,
    height: 38,
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
  employeeText: {
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
