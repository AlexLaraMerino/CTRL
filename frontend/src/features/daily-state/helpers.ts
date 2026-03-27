import { addDays, getWorkWeek } from './date';
import { Coordinates, DailyState, EmployeePlacement, WorkSite } from './domain';

export type DailyStatesByDate = Record<string, DailyState>;
const DEFAULT_UNASSIGNED_POSITION = { lat: 40.2, lng: -3.7 };

function cloneEmployeePlacement(placement: EmployeePlacement): EmployeePlacement {
  return { ...placement };
}

export function normalizeDailyState(dailyState: DailyState): DailyState {
  return {
    ...dailyState,
    visibleWorkSiteIds: dailyState.visibleWorkSiteIds ?? [],
    absentEmployeeIds: dailyState.absentEmployeeIds ?? [],
    employeePlacements: dailyState.employeePlacements ?? {},
  };
}

export function cloneDailyState(dailyState: DailyState, nextDate = dailyState.date): DailyState {
  const normalized = normalizeDailyState(dailyState);

  return {
    date: nextDate,
    notes: normalized.notes,
    visibleWorkSiteIds: [...normalized.visibleWorkSiteIds],
    absentEmployeeIds: [...normalized.absentEmployeeIds],
    employeePlacements: Object.fromEntries(
      Object.entries(normalized.employeePlacements).map(([employeeId, placement]) => [
        employeeId,
        cloneEmployeePlacement(placement),
      ]),
    ),
  };
}

export function ensureDailyState(
  dailyStates: DailyStatesByDate,
  date: string,
  createState: (date: string) => DailyState,
) {
  if (dailyStates[date]) {
    return dailyStates;
  }

  return {
    ...dailyStates,
    [date]: createState(date),
  };
}

export function getDailyState(
  dailyStates: DailyStatesByDate,
  date: string,
  createState: (date: string) => DailyState,
) {
  return normalizeDailyState(dailyStates[date] ?? createState(date));
}

export function setDailyStateNotes(dailyState: DailyState, notes: string): DailyState {
  const normalized = normalizeDailyState(dailyState);

  return {
    ...normalized,
    notes,
  };
}

export function isWorkSiteVisible(dailyState: DailyState, workSiteId: string) {
  return normalizeDailyState(dailyState).visibleWorkSiteIds.includes(workSiteId);
}

export function toggleVisibleWorkSiteId(dailyState: DailyState, workSiteId: string): DailyState {
  const normalized = normalizeDailyState(dailyState);
  const isVisible = isWorkSiteVisible(normalized, workSiteId);

  return {
    ...normalized,
    visibleWorkSiteIds: isVisible
      ? normalized.visibleWorkSiteIds.filter((id) => id !== workSiteId)
      : [...normalized.visibleWorkSiteIds, workSiteId],
  };
}

export function isEmployeeAbsent(dailyState: DailyState, employeeId: string) {
  return normalizeDailyState(dailyState).absentEmployeeIds.includes(employeeId);
}

export function toggleEmployeeAbsence(dailyState: DailyState, employeeId: string): DailyState {
  const normalized = normalizeDailyState(dailyState);
  const absent = isEmployeeAbsent(normalized, employeeId);

  return {
    ...normalized,
    absentEmployeeIds: absent
      ? normalized.absentEmployeeIds.filter((id) => id !== employeeId)
      : [...normalized.absentEmployeeIds, employeeId],
  };
}

export function findNearestWorkSiteId(coordinates: Coordinates, workSites: WorkSite[]) {
  let winner: { id: string; distance: number } | null = null;

  for (const workSite of workSites) {
    const latDiff = coordinates.lat - workSite.lat;
    const lngDiff = coordinates.lng - workSite.lng;
    const distance = Math.sqrt(latDiff ** 2 + lngDiff ** 2);

    if (!winner || distance < winner.distance) {
      winner = { id: workSite.id, distance };
    }
  }

  if (!winner || winner.distance > 0.45) {
    return null;
  }

  return winner.id;
}

export function moveEmployeePlacement(
  dailyState: DailyState,
  employeeId: string,
  coordinates: Coordinates,
  workSites: WorkSite[],
): DailyState {
  const normalized = normalizeDailyState(dailyState);
  const workSiteId = findNearestWorkSiteId(coordinates, workSites);

  return {
    ...normalized,
    employeePlacements: {
      ...normalized.employeePlacements,
      [employeeId]: {
        employeeId,
        workSiteId,
        lat: coordinates.lat,
        lng: coordinates.lng,
      },
    },
  };
}

export function copyDailyStateToDate(sourceState: DailyState, targetDate: string): DailyState {
  return cloneDailyState(sourceState, targetDate);
}

export function copyDateConfiguration(
  dailyStates: DailyStatesByDate,
  sourceDate: string,
  targetDate: string,
  createState: (date: string) => DailyState,
) {
  const sourceState = getDailyState(dailyStates, sourceDate, createState);

  return {
    ...ensureDailyState(dailyStates, sourceDate, createState),
    [targetDate]: copyDailyStateToDate(sourceState, targetDate),
  };
}

export function copyPreviousDateConfiguration(
  dailyStates: DailyStatesByDate,
  date: string,
  createState: (date: string) => DailyState,
) {
  return copyDateConfiguration(dailyStates, addDays(date, -1), date, createState);
}

export function applyDateConfigurationToWeek(
  dailyStates: DailyStatesByDate,
  sourceDate: string,
  includeWeekend: boolean,
  createState: (date: string) => DailyState,
) {
  const sourceState = getDailyState(dailyStates, sourceDate, createState);
  const nextStates = { ...ensureDailyState(dailyStates, sourceDate, createState) };

  for (const targetDate of getWorkWeek(sourceDate, includeWeekend)) {
    if (targetDate !== sourceDate) {
      nextStates[targetDate] = copyDailyStateToDate(sourceState, targetDate);
    }
  }

  return nextStates;
}

export function addEmployeeToDailyStates(
  dailyStates: DailyStatesByDate,
  employeeId: string,
) {
  return Object.fromEntries(
    Object.entries(dailyStates).map(([date, dailyState]) => [
      date,
      {
        ...dailyState,
        absentEmployeeIds: dailyState.absentEmployeeIds.filter((id) => id !== employeeId),
        employeePlacements: {
          ...dailyState.employeePlacements,
          [employeeId]: {
            employeeId,
            workSiteId: null,
            lat: DEFAULT_UNASSIGNED_POSITION.lat,
            lng: DEFAULT_UNASSIGNED_POSITION.lng,
          },
        },
      },
    ]),
  );
}

export function removeEmployeeFromDailyStates(
  dailyStates: DailyStatesByDate,
  employeeId: string,
) {
  return Object.fromEntries(
    Object.entries(dailyStates).map(([date, dailyState]) => {
      const nextPlacements = { ...dailyState.employeePlacements };
      delete nextPlacements[employeeId];

      return [
        date,
      {
        ...dailyState,
        absentEmployeeIds: dailyState.absentEmployeeIds.filter((id) => id !== employeeId),
        employeePlacements: nextPlacements,
      },
      ];
    }),
  );
}

export function addWorkSiteToDailyStates(
  dailyStates: DailyStatesByDate,
  workSiteId: string,
) {
  return Object.fromEntries(
    Object.entries(dailyStates).map(([date, dailyState]) => [
      date,
      {
        ...dailyState,
        visibleWorkSiteIds: dailyState.visibleWorkSiteIds.includes(workSiteId)
          ? dailyState.visibleWorkSiteIds
          : [...dailyState.visibleWorkSiteIds, workSiteId],
      },
    ]),
  );
}

export function removeWorkSiteFromDailyStates(
  dailyStates: DailyStatesByDate,
  workSiteId: string,
) {
  return Object.fromEntries(
    Object.entries(dailyStates).map(([date, dailyState]) => [
      date,
      {
        ...dailyState,
        visibleWorkSiteIds: dailyState.visibleWorkSiteIds.filter((id) => id !== workSiteId),
        absentEmployeeIds: [...dailyState.absentEmployeeIds],
        employeePlacements: Object.fromEntries(
          Object.entries(dailyState.employeePlacements).map(([employeeId, placement]) => [
            employeeId,
            placement.workSiteId === workSiteId
              ? {
                  ...placement,
                  workSiteId: null,
                }
              : placement,
          ]),
        ),
      },
    ]),
  );
}
