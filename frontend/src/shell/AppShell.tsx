import { useEffect, useMemo, useState } from 'react';
import { StyleSheet, Text, Vibration, View, useWindowDimensions } from 'react-native';

import { normalizeDailyState } from '../features/daily-state/helpers';
import { createSeedDailyState } from '../features/daily-state/mockData';
import { HeaderBar } from '../features/header/HeaderBar';
import { OperationalMap } from '../features/map/components/OperationalMap';
import { LeftDrawer } from '../features/panels/LeftDrawer';
import { EmployeesDrawer } from '../features/panels/EmployeesDrawer';
import { WorkSitesDrawer } from '../features/panels/WorkSitesDrawer';
import { useDailyBoardStore } from '../store/useDailyBoardStore';
import { colors } from '../theme/tokens';

const HEADER_HEIGHT = 62;

type RelocationSession = {
  employeeId: string;
  point: { pageX: number; pageY: number } | null;
  source: 'panel' | 'map';
};

export function AppShell() {
  const { width } = useWindowDimensions();
  const [leftOpen, setLeftOpen] = useState(true);
  const [employeesOpen, setEmployeesOpen] = useState(false);
  const [workSitesOpen, setWorkSitesOpen] = useState(false);
  const [relocationSession, setRelocationSession] = useState<RelocationSession | null>(null);
  const [relocationDropPoint, setRelocationDropPoint] = useState<{ pageX: number; pageY: number } | null>(null);

  const selectedDate = useDailyBoardStore((state) => state.selectedDate);
  const employees = useDailyBoardStore((state) => state.employees);
  const activeEmployees = useMemo(
    () => employees.filter((employee) => employee.active),
    [employees],
  );
  const workSites = useDailyBoardStore((state) => state.workSites);
  const storedDailyState = useDailyBoardStore((state) => state.dailyStates[selectedDate]);
  const ensureDay = useDailyBoardStore((state) => state.ensureDay);
  const selectDate = useDailyBoardStore((state) => state.selectDate);
  const setNotes = useDailyBoardStore((state) => state.setNotes);
  const toggleWorkSiteVisibility = useDailyBoardStore((state) => state.toggleWorkSiteVisibility);
  const moveEmployee = useDailyBoardStore((state) => state.moveEmployee);
  const copyDay = useDailyBoardStore((state) => state.copyDay);
  const copyPreviousDay = useDailyBoardStore((state) => state.copyPreviousDay);
  const applyToWorkWeek = useDailyBoardStore((state) => state.applyToWorkWeek);
  const toggleEmployeeAbsence = useDailyBoardStore((state) => state.toggleEmployeeAbsence);
  const addEmployee = useDailyBoardStore((state) => state.addEmployee);
  const updateEmployee = useDailyBoardStore((state) => state.updateEmployee);
  const setEmployeeActive = useDailyBoardStore((state) => state.setEmployeeActive);
  const addWorkSite = useDailyBoardStore((state) => state.addWorkSite);
  const updateWorkSite = useDailyBoardStore((state) => state.updateWorkSite);
  const removeWorkSite = useDailyBoardStore((state) => state.removeWorkSite);

  const dailyState = useMemo(
    () =>
      storedDailyState
        ? normalizeDailyState(storedDailyState)
        : createSeedDailyState(selectedDate, employees, workSites),
    [employees, selectedDate, storedDailyState, workSites],
  );

  useEffect(() => {
    ensureDay(selectedDate);
  }, [ensureDay, selectedDate]);

  const leftDrawerWidth = Math.min(320, width - 72);
  const rightDrawerWidth = Math.min(340, width - 72);

  if (Object.keys(dailyState.employeePlacements).length === 0) {
    return (
      <View style={styles.loading}>
        <Text style={styles.loadingText}>Cargando tablero operativo...</Text>
      </View>
    );
  }

  const handleStartRelocation = (
    employeeId: string,
    point: { pageX: number; pageY: number },
    source: 'panel' | 'map',
  ) => {
    Vibration.vibrate(20);
    setWorkSitesOpen(false);
    if (source === 'map') {
      setEmployeesOpen(false);
    }
    setRelocationDropPoint(null);
    setRelocationSession({ employeeId, point, source });
  };

  const handleMoveRelocation = (point: { pageX: number; pageY: number }) => {
    setRelocationSession((current) => (current ? { ...current, point } : current));
  };

  const handleDropRelocation = (point: { pageX: number; pageY: number }) => {
    setRelocationSession((current) => (current ? { ...current, point } : current));
    setRelocationDropPoint(point);
    setEmployeesOpen(false);
    setWorkSitesOpen(false);
  };

  return (
    <View style={styles.screen}>
      <View style={styles.mapLayer}>
        <OperationalMap
          dailyState={dailyState}
          employees={activeEmployees}
          workSites={workSites}
          relocatingEmployeeId={relocationSession?.employeeId ?? null}
          relocationPoint={relocationSession?.point ?? null}
          relocationDropPoint={relocationDropPoint}
          onMoveEmployee={(employeeId: string, latitude: number, longitude: number) =>
            moveEmployee(selectedDate, employeeId, { lat: latitude, lng: longitude })
          }
          onStartRelocation={handleStartRelocation}
          onMoveRelocation={handleMoveRelocation}
          onDropRelocation={handleDropRelocation}
          onPlaceRelocatingEmployee={(employeeId, latitude, longitude) => {
            moveEmployee(selectedDate, employeeId, { lat: latitude, lng: longitude });
            setRelocationDropPoint(null);
            setRelocationSession(null);
          }}
        />
      </View>

      <View style={styles.topBarWrap} pointerEvents="box-none">
        <HeaderBar
          selectedDate={selectedDate}
          onSelectDate={selectDate}
          onOpenLeftPanel={() => setLeftOpen(true)}
          onOpenEmployeesPanel={() => {
            setEmployeesOpen(true);
            setWorkSitesOpen(false);
          }}
          onOpenWorkSitesPanel={() => {
            setWorkSitesOpen(true);
            setEmployeesOpen(false);
          }}
        />
      </View>

      <LeftDrawer
        selectedDate={selectedDate}
        dailyState={dailyState}
        isOpen={leftOpen}
        width={leftDrawerWidth}
        topOffset={HEADER_HEIGHT + 28}
        onOpen={() => setLeftOpen(true)}
        onClose={() => setLeftOpen(false)}
        onSelectDate={selectDate}
        onSetNotes={(notes) => setNotes(selectedDate, notes)}
        onCopyYesterday={() => copyPreviousDay(selectedDate)}
        onCopyDay={(targetDate) => copyDay(selectedDate, targetDate)}
        onApplyWeek={(includeWeekend) => applyToWorkWeek(selectedDate, includeWeekend)}
      />

      <EmployeesDrawer
        employees={employees}
        dailyState={dailyState}
        isOpen={employeesOpen}
        hidden={workSitesOpen}
        width={rightDrawerWidth}
        topOffset={HEADER_HEIGHT + 28}
        onOpen={() => {
          setEmployeesOpen(true);
          setWorkSitesOpen(false);
        }}
        onClose={() => setEmployeesOpen(false)}
        onAddEmployee={addEmployee}
        onUpdateEmployee={updateEmployee}
        onSetEmployeeActive={setEmployeeActive}
        onToggleAbsence={(employeeId) => toggleEmployeeAbsence(selectedDate, employeeId)}
        onStartRelocation={handleStartRelocation}
        onMoveRelocation={handleMoveRelocation}
        onDropRelocation={handleDropRelocation}
        relocating={relocationSession?.source === 'panel'}
      />

      <WorkSitesDrawer
        workSites={workSites}
        isOpen={workSitesOpen}
        hidden={employeesOpen}
        width={rightDrawerWidth}
        topOffset={HEADER_HEIGHT + 28}
        onOpen={() => {
          setWorkSitesOpen(true);
          setEmployeesOpen(false);
        }}
        onClose={() => setWorkSitesOpen(false)}
        onAddWorkSite={addWorkSite}
        onUpdateWorkSite={updateWorkSite}
        onRemoveWorkSite={removeWorkSite}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: colors.bg,
  },
  mapLayer: {
    ...StyleSheet.absoluteFillObject,
  },
  topBarWrap: {
    position: 'absolute',
    top: 16,
    left: 16,
    right: 16,
  },
  loading: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.bg,
  },
  loadingText: {
    color: colors.text,
    fontSize: 18,
    fontWeight: '700',
  },
});
