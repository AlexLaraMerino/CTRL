import AsyncStorage from '@react-native-async-storage/async-storage';
import { create } from 'zustand';
import { createJSONStorage, persist } from 'zustand/middleware';

import { getSpainDateKey } from '../features/daily-state/date';
import {
  addEmployeeToDailyStates,
  addWorkSiteToDailyStates,
  applyDateConfigurationToWeek,
  copyDateConfiguration,
  copyPreviousDateConfiguration,
  DailyStatesByDate,
  ensureDailyState,
  getDailyState,
  moveEmployeePlacement,
  removeWorkSiteFromDailyStates,
  setDailyStateNotes,
  toggleEmployeeAbsence,
  toggleVisibleWorkSiteId,
} from '../features/daily-state/helpers';
import { Coordinates, EmployeeRecord, WorkSite } from '../features/daily-state/domain';
import { createSeedDailyState, seedEmployees, seedWorkSites } from '../features/daily-state/mockData';

type BoardState = {
  selectedDate: string;
  employees: EmployeeRecord[];
  workSites: WorkSite[];
  dailyStates: DailyStatesByDate;
  selectDate: (dateKey: string) => void;
  ensureDay: (dateKey: string) => void;
  setNotes: (dateKey: string, notes: string) => void;
  toggleWorkSiteVisibility: (dateKey: string, workSiteId: string) => void;
  moveEmployee: (dateKey: string, employeeId: string, coordinates: Coordinates) => void;
  toggleEmployeeAbsence: (dateKey: string, employeeId: string) => void;
  copyDay: (sourceDate: string, targetDate: string) => void;
  copyPreviousDay: (dateKey: string) => void;
  applyToWorkWeek: (sourceDate: string, includeWeekend: boolean) => void;
  addEmployee: (name: string) => void;
  updateEmployee: (employeeId: string, name: string) => void;
  setEmployeeActive: (employeeId: string, active: boolean) => void;
  addWorkSite: (input: { name: string; city: string; lat: number; lng: number }) => void;
  updateWorkSite: (
    workSiteId: string,
    input: { name: string; city: string; lat: number; lng: number },
  ) => void;
  removeWorkSite: (workSiteId: string) => void;
};

const employeePalette = ['#22c55e', '#10b981', '#84cc16', '#14b8a6', '#06b6d4', '#0ea5e9'];

function buildDailyStateFactory(employees: EmployeeRecord[], workSites: WorkSite[]) {
  return (date: string) => createSeedDailyState(date, employees, workSites);
}

function makeId(prefix: string) {
  return `${prefix}-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 7)}`;
}

export const useDailyBoardStore = create<BoardState>()(
  persist(
    (set, get) => ({
      selectedDate: getSpainDateKey(),
      employees: seedEmployees,
      workSites: seedWorkSites,
      dailyStates: {},
      selectDate: (dateKey) => {
        get().ensureDay(dateKey);
        set({ selectedDate: dateKey });
      },
      ensureDay: (dateKey) =>
        set((state) => ({
          dailyStates: ensureDailyState(
            state.dailyStates,
            dateKey,
            buildDailyStateFactory(state.employees, state.workSites),
          ),
        })),
      setNotes: (dateKey, notes) =>
        set((state) => {
          const dailyState = getDailyState(
            state.dailyStates,
            dateKey,
            buildDailyStateFactory(state.employees, state.workSites),
          );

          return {
            dailyStates: {
              ...state.dailyStates,
              [dateKey]: setDailyStateNotes(dailyState, notes),
            },
          };
        }),
      toggleWorkSiteVisibility: (dateKey, workSiteId) =>
        set((state) => {
          const dailyState = getDailyState(
            state.dailyStates,
            dateKey,
            buildDailyStateFactory(state.employees, state.workSites),
          );

          return {
            dailyStates: {
              ...state.dailyStates,
              [dateKey]: toggleVisibleWorkSiteId(dailyState, workSiteId),
            },
          };
        }),
      moveEmployee: (dateKey, employeeId, coordinates) =>
        set((state) => {
          const dailyState = getDailyState(
            state.dailyStates,
            dateKey,
            buildDailyStateFactory(state.employees, state.workSites),
          );

          return {
            dailyStates: {
              ...state.dailyStates,
              [dateKey]: moveEmployeePlacement(dailyState, employeeId, coordinates, state.workSites),
            },
          };
        }),
      toggleEmployeeAbsence: (dateKey, employeeId) =>
        set((state) => {
          const dailyState = getDailyState(
            state.dailyStates,
            dateKey,
            buildDailyStateFactory(state.employees, state.workSites),
          );

          return {
            dailyStates: {
              ...state.dailyStates,
              [dateKey]: toggleEmployeeAbsence(dailyState, employeeId),
            },
          };
        }),
      copyDay: (sourceDate, targetDate) =>
        set((state) => ({
          dailyStates: copyDateConfiguration(
            state.dailyStates,
            sourceDate,
            targetDate,
            buildDailyStateFactory(state.employees, state.workSites),
          ),
        })),
      copyPreviousDay: (dateKey) =>
        set((state) => ({
          dailyStates: copyPreviousDateConfiguration(
            state.dailyStates,
            dateKey,
            buildDailyStateFactory(state.employees, state.workSites),
          ),
        })),
      applyToWorkWeek: (sourceDate, includeWeekend) =>
        set((state) => ({
          dailyStates: applyDateConfigurationToWeek(
            state.dailyStates,
            sourceDate,
            includeWeekend,
            buildDailyStateFactory(state.employees, state.workSites),
          ),
        })),
      addEmployee: (name) =>
        set((state) => {
          const employeeId = makeId('emp');
          const employee: EmployeeRecord = {
            id: employeeId,
            name,
            color: employeePalette[state.employees.length % employeePalette.length],
            active: true,
          };

          return {
            employees: [...state.employees, employee],
            dailyStates: addEmployeeToDailyStates(state.dailyStates, employeeId),
          };
        }),
      updateEmployee: (employeeId, name) =>
        set((state) => ({
          employees: state.employees.map((employee) =>
            employee.id === employeeId ? { ...employee, name } : employee,
          ),
        })),
      setEmployeeActive: (employeeId, active) =>
        set((state) => ({
          employees: state.employees.map((employee) =>
            employee.id === employeeId ? { ...employee, active } : employee,
          ),
          dailyStates: state.dailyStates,
        })),
      addWorkSite: ({ name, city, lat, lng }) =>
        set((state) => {
          const workSite: WorkSite = {
            id: makeId('work'),
            name,
            city,
            lat,
            lng,
          };

          return {
            workSites: [...state.workSites, workSite],
            dailyStates: addWorkSiteToDailyStates(state.dailyStates, workSite.id),
          };
        }),
      updateWorkSite: (workSiteId, input) =>
        set((state) => ({
          workSites: state.workSites.map((workSite) =>
            workSite.id === workSiteId ? { ...workSite, ...input } : workSite,
          ),
        })),
      removeWorkSite: (workSiteId) =>
        set((state) => ({
          workSites: state.workSites.filter((workSite) => workSite.id !== workSiteId),
          dailyStates: removeWorkSiteFromDailyStates(state.dailyStates, workSiteId),
        })),
    }),
    {
      name: 'ctrl-daily-board-v2',
      storage: createJSONStorage(() => AsyncStorage),
      partialize: (state) => ({
        selectedDate: state.selectedDate,
        employees: state.employees,
        workSites: state.workSites,
        dailyStates: state.dailyStates,
      }),
    },
  ),
);
