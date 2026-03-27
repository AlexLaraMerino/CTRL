import { DailyState, EmployeeRecord, WorkSite } from './domain';

export const seedEmployees: EmployeeRecord[] = [
  { id: 'emp-1', name: 'Javier', color: '#22c55e', active: true },
  { id: 'emp-2', name: 'Lucia', color: '#10b981', active: true },
  { id: 'emp-3', name: 'Marcos', color: '#84cc16', active: true },
  { id: 'emp-4', name: 'Sara', color: '#14b8a6', active: true },
  { id: 'emp-5', name: 'Nora', color: '#06b6d4', active: true },
  { id: 'emp-6', name: 'Iker', color: '#0ea5e9', active: true },
];

export const seedWorkSites: WorkSite[] = [
  {
    id: 'work-1',
    name: 'Reforma Castellana',
    city: 'Madrid',
    lat: 40.4168,
    lng: -3.7038,
  },
  {
    id: 'work-2',
    name: 'Climatizacion Expo',
    city: 'Zaragoza',
    lat: 41.6488,
    lng: -0.8891,
  },
  {
    id: 'work-3',
    name: 'Hotel Puerto',
    city: 'Valencia',
    lat: 39.4699,
    lng: -0.3763,
  },
  {
    id: 'work-4',
    name: 'Residencial Sur',
    city: 'Malaga',
    lat: 36.7213,
    lng: -4.4214,
  },
  {
    id: 'work-5',
    name: 'Parque Norte',
    city: 'Bilbao',
    lat: 43.263,
    lng: -2.935,
  },
];

const initialAssignments = [
  { employeeId: 'emp-1', workSiteId: 'work-1', latOffset: 0.02, lngOffset: -0.03 },
  { employeeId: 'emp-2', workSiteId: 'work-1', latOffset: -0.03, lngOffset: 0.04 },
  { employeeId: 'emp-3', workSiteId: 'work-2', latOffset: 0.02, lngOffset: 0.02 },
  { employeeId: 'emp-4', workSiteId: 'work-3', latOffset: -0.02, lngOffset: -0.02 },
  { employeeId: 'emp-5', workSiteId: 'work-4', latOffset: 0.03, lngOffset: 0.02 },
  { employeeId: 'emp-6', workSiteId: 'work-5', latOffset: -0.02, lngOffset: 0.03 },
];

export function createSeedDailyState(
  date: string,
  employees: EmployeeRecord[] = seedEmployees,
  workSites: WorkSite[] = seedWorkSites,
): DailyState {
  const visibleWorkSiteIds = workSites.map((workSite) => workSite.id);

  const employeePlacements = Object.fromEntries(
    employees.map((employee) => {
      const assignment = initialAssignments.find((item) => item.employeeId === employee.id);
      const workSite = workSites.find((item) => item.id === assignment?.workSiteId);

      if (!assignment || !workSite) {
        return [
          employee.id,
          {
            employeeId: employee.id,
            workSiteId: null,
            lat: 40.2,
            lng: -3.7,
          },
        ];
      }

      return [
        employee.id,
        {
          employeeId: employee.id,
          workSiteId: assignment.workSiteId,
          lat: workSite.lat + assignment.latOffset,
          lng: workSite.lng + assignment.lngOffset,
        },
      ];
    }),
  );

  return {
    date,
    notes: '',
    visibleWorkSiteIds,
    absentEmployeeIds: [],
    employeePlacements,
  };
}
