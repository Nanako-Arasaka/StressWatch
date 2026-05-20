export function startOfDay(date: Date): Date {
  const next = new Date(date);
  next.setHours(0, 0, 0, 0);
  return next;
}

export function endOfDay(date: Date): Date {
  const next = startOfDay(date);
  next.setDate(next.getDate() + 1);
  next.setMilliseconds(-1);
  return next;
}

export function daysAgo(days: number, from = new Date()): Date {
  const next = startOfDay(from);
  next.setDate(next.getDate() - days);
  return next;
}

export function isSameDay(a: string | Date, b: string | Date): boolean {
  const first = startOfDay(new Date(a));
  const second = startOfDay(new Date(b));
  return first.getTime() === second.getTime();
}

export function formatShortDate(value: string): string {
  return new Intl.DateTimeFormat("zh-CN", {
    month: "numeric",
    day: "numeric"
  }).format(new Date(value));
}
