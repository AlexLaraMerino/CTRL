import { ComponentType } from 'react';
import { Platform } from 'react-native';

import { DailyState, EmployeeRecord, WorkSite } from '../../daily-state/domain';

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

const implementation =
  Platform.OS === 'web'
    ? require('./OperationalMap.web').OperationalMap
    : require('./OperationalMap.native').OperationalMap;

export const OperationalMap = implementation as ComponentType<OperationalMapProps>;
