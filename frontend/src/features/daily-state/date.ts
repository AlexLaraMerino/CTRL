const SPAIN_TIME_ZONE = 'Europe/Madrid';

function getParts(date: Date) {
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone: SPAIN_TIME_ZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });

  return formatter.formatToParts(date);
}

export function getSpainDateKey(date = new Date()) {
  const parts = getParts(date);
  const year = parts.find((part) => part.type === 'year')?.value ?? '1970';
  const month = parts.find((part) => part.type === 'month')?.value ?? '01';
  const day = parts.find((part) => part.type === 'day')?.value ?? '01';

  return `${year}-${month}-${day}`;
}

export function addDays(dateKey: string, delta: number) {
  const [year, month, day] = dateKey.split('-').map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));

  date.setUTCDate(date.getUTCDate() + delta);

  return getSpainDateKey(date);
}

export function addMonths(dateKey: string, delta: number) {
  const [year, month, day] = dateKey.split('-').map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));

  date.setUTCMonth(date.getUTCMonth() + delta);

  return getSpainDateKey(date);
}

export function formatDateLabel(dateKey: string) {
  const [year, month, day] = dateKey.split('-').map(Number);

  return new Intl.DateTimeFormat('es-ES', {
    weekday: 'short',
    day: 'numeric',
    month: 'short',
    timeZone: SPAIN_TIME_ZONE,
  }).format(new Date(Date.UTC(year, month - 1, day)));
}

export function formatDateFull(dateKey: string) {
  const [year, month, day] = dateKey.split('-').map(Number);

  return new Intl.DateTimeFormat('es-ES', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
    timeZone: SPAIN_TIME_ZONE,
  }).format(new Date(Date.UTC(year, month - 1, day)));
}

export function formatMonthYear(dateKey: string) {
  const [year, month] = dateKey.split('-').map(Number);

  return new Intl.DateTimeFormat('es-ES', {
    month: 'long',
    year: 'numeric',
    timeZone: SPAIN_TIME_ZONE,
  }).format(new Date(Date.UTC(year, month - 1, 1)));
}

export function getWeekStrip(dateKey: string, total = 7) {
  const start = -Math.floor(total / 2);

  return Array.from({ length: total }, (_, index) => addDays(dateKey, start + index));
}

export function getWorkWeek(dateKey: string, includeWeekend = false) {
  const [year, month, day] = dateKey.split('-').map(Number);
  const current = new Date(Date.UTC(year, month - 1, day));
  const weekday = current.getUTCDay();
  const distanceToMonday = weekday === 0 ? -6 : 1 - weekday;
  const monday = addDays(dateKey, distanceToMonday);
  const totalDays = includeWeekend ? 7 : 5;

  return Array.from({ length: totalDays }, (_, index) => addDays(monday, index));
}

export function isSameDate(a: string, b: string) {
  return a === b;
}

export function isSameMonth(a: string, b: string) {
  return a.slice(0, 7) === b.slice(0, 7);
}

export function getMonthCalendar(dateKey: string) {
  const [year, month] = dateKey.split('-').map(Number);
  const monthStart = new Date(Date.UTC(year, month - 1, 1));
  const monthIndex = monthStart.getUTCMonth();
  const leadingDays = monthStart.getUTCDay() === 0 ? 6 : monthStart.getUTCDay() - 1;
  const gridStart = new Date(Date.UTC(year, month - 1, 1 - leadingDays));

  return Array.from({ length: 42 }, (_, index) => {
    const current = new Date(gridStart);
    current.setUTCDate(gridStart.getUTCDate() + index);

    return {
      dateKey: getSpainDateKey(current),
      dayNumber: current.getUTCDate(),
      inCurrentMonth: current.getUTCMonth() === monthIndex,
    };
  });
}
