const ACTIVE = ['online', 'busy'];
const HOUR = 3600;

const emptyGrid = () => Array.from({ length: 7 }, () => Array(24).fill(0));

/**
 * How many agents were connected (online or busy) at each hour, averaged over the days
 * of the period. Built from each agent's status segments ({ status, from, to } in unix
 * seconds) and split at local hour boundaries.
 *
 * @param {Array<{ timeline: Array }>} rows - activity report rows
 * @param {number} dayCount - days in the period, the divisor for the average
 * @returns {{ byHour: number[], byWeekdayHour: number[][] }} average agents per hour of
 *   the day, and per weekday (0 = Sunday) and hour
 */
export const presenceCoverage = (rows, dayCount) => {
  const seconds = emptyGrid();
  const days = Math.max(dayCount, 1);

  rows.forEach(row => {
    (row.timeline || [])
      .filter(segment => ACTIVE.includes(segment.status))
      .forEach(segment => {
        let cursor = segment.from;
        while (cursor < segment.to) {
          const slotStart = new Date(cursor * 1000);
          const nextHour =
            new Date(
              slotStart.getFullYear(),
              slotStart.getMonth(),
              slotStart.getDate(),
              slotStart.getHours() + 1
            ).getTime() / 1000;
          const slotEnd = Math.min(nextHour, segment.to);
          seconds[slotStart.getDay()][slotStart.getHours()] += slotEnd - cursor;
          cursor = slotEnd;
        }
      });
  });

  const round = value => Math.round(value * 10) / 10;
  const byHour = Array.from({ length: 24 }, (_, hour) =>
    round(seconds.reduce((sum, day) => sum + day[hour], 0) / (HOUR * days))
  );

  // A weekday occurs once per week, so divide by how many weeks the period spans
  const weeks = Math.max(Math.ceil(days / 7), 1);
  const byWeekdayHour = seconds.map(day =>
    day.map(value => round(value / (HOUR * weeks)))
  );

  return { byHour, byWeekdayHour };
};
