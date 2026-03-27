export type Coordinates = {
  lat: number;
  lng: number;
};

export type Employee = {
  id: string;
  name: string;
};

export type EmployeeRecord = Employee & {
  color: string;
  active: boolean;
};

export type WorkSite = Coordinates & {
  id: string;
  name: string;
  city: string;
};

export type EmployeePlacement = Coordinates & {
  employeeId: string;
  workSiteId: string | null;
};

export type DailyState = {
  date: string;
  notes: string;
  visibleWorkSiteIds: string[];
  absentEmployeeIds: string[];
  employeePlacements: Record<string, EmployeePlacement>;
};
