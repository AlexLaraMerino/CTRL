import { DailyState, EmployeePlacement, EmployeeRecord, WorkSite } from '../daily-state/domain';
import { isEmployeeAbsent, isWorkSiteVisible } from '../daily-state/helpers';

const GROUP_RADIUS = 0.09;
const ORBIT_RADIUS = 0.07;

export type MapEmployeeMarker = {
  employeeId: string;
  name: string;
  color: string;
  lat: number;
  lng: number;
  compact: boolean;
  workSiteId: string | null;
};

export type MapEmployeeGroup = {
  id: string;
  workSiteId: string;
  lat: number;
  lng: number;
  count: number;
  employeeNames: string[];
};

export type MapWorkSiteMarker = {
  id: string;
  name: string;
  city: string;
  lat: number;
  lng: number;
  assignedCount: number;
};

function getDistance(a: { lat: number; lng: number }, b: { lat: number; lng: number }) {
  const latDiff = a.lat - b.lat;
  const lngDiff = a.lng - b.lng;

  return Math.sqrt(latDiff ** 2 + lngDiff ** 2);
}

function createOrbitPoint(workSite: WorkSite, index: number, total: number) {
  const angle = (Math.PI * 2 * index) / Math.max(total, 1);

  return {
    lat: workSite.lat + Math.sin(angle) * ORBIT_RADIUS,
    lng: workSite.lng + Math.cos(angle) * ORBIT_RADIUS,
  };
}

function shouldGroupPlacements(workSite: WorkSite, placements: EmployeePlacement[]) {
  return (
    placements.length > 1 &&
    placements.every((placement) => getDistance(placement, workSite) <= GROUP_RADIUS)
  );
}

export function buildMapPresentation(
  dailyState: DailyState,
  employees: EmployeeRecord[],
  workSites: WorkSite[],
  relocatingEmployeeId?: string | null,
) {
  const visibleWorkSites = workSites.filter((workSite) => isWorkSiteVisible(dailyState, workSite.id));
  const placementsByWorkSite = Object.values(dailyState.employeePlacements).reduce<Record<string, EmployeePlacement[]>>(
    (accumulator, placement) => {
      if (
        placement.workSiteId &&
        !isEmployeeAbsent(dailyState, placement.employeeId) &&
        placement.employeeId !== relocatingEmployeeId
      ) {
        accumulator[placement.workSiteId] = [...(accumulator[placement.workSiteId] ?? []), placement];
      }

      return accumulator;
    },
    {},
  );

  const groupedWorkSiteIds = new Set(
    workSites
      .filter((workSite) => shouldGroupPlacements(workSite, placementsByWorkSite[workSite.id] ?? []))
      .map((workSite) => workSite.id),
  );

  const employeeMarkers: MapEmployeeMarker[] = [];
  const employeeGroups: MapEmployeeGroup[] = [];

  for (const workSite of workSites) {
    const placements = placementsByWorkSite[workSite.id] ?? [];
    const isGrouped = groupedWorkSiteIds.has(workSite.id);

    if (isGrouped) {
      employeeGroups.push({
        id: `group-${workSite.id}`,
        workSiteId: workSite.id,
        lat: workSite.lat - 0.035,
        lng: workSite.lng + 0.035,
        count: placements.length,
        employeeNames: placements
          .map((placement) => employees.find((employee) => employee.id === placement.employeeId)?.name ?? placement.employeeId),
      });
    }

    placements.forEach((placement, index) => {
      const employee = employees.find((item) => item.id === placement.employeeId);

      if (!employee) {
        return;
      }

      const orbitPoint = isGrouped ? createOrbitPoint(workSite, index, placements.length) : placement;

      employeeMarkers.push({
        employeeId: employee.id,
        name: employee.name,
        color: employee.color,
        lat: orbitPoint.lat,
        lng: orbitPoint.lng,
        compact: isGrouped,
        workSiteId: placement.workSiteId,
      });
    });
  }

  for (const employee of employees) {
    const placement = dailyState.employeePlacements[employee.id];

    if (
      !placement ||
      placement.workSiteId ||
      isEmployeeAbsent(dailyState, employee.id) ||
      employee.id === relocatingEmployeeId
    ) {
      continue;
    }

    employeeMarkers.push({
      employeeId: employee.id,
      name: employee.name,
      color: employee.color,
      lat: placement.lat,
      lng: placement.lng,
      compact: false,
      workSiteId: null,
    });
  }

  const workSiteMarkers: MapWorkSiteMarker[] = visibleWorkSites.map((workSite) => ({
    id: workSite.id,
    name: workSite.name,
    city: workSite.city,
    lat: workSite.lat,
    lng: workSite.lng,
    assignedCount: placementsByWorkSite[workSite.id]?.length ?? 0,
  }));

  return {
    workSiteMarkers,
    employeeMarkers,
    employeeGroups,
    groupedTeamsCount: employeeGroups.length,
  };
}
