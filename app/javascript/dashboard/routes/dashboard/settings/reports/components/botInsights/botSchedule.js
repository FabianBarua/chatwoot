// Helpers for the "when customers write" tab of the bot report. `cells` is the weekday x hour
// list returned by the API: [{ weekday, hour, count }], weekday 0 = Sunday.

export const totalsBy = (cells, key) =>
  cells.reduce((totals, cell) => {
    totals[cell[key]] = (totals[cell[key]] || 0) + cell.count;
    return totals;
  }, {});

// The key with the highest total, or null when there is nothing
export const busiest = totals => {
  const entries = Object.entries(totals);
  if (!entries.length) return null;
  const [key, count] = entries.reduce((best, entry) =>
    entry[1] > best[1] ? entry : best
  );
  return { key: Number(key), count };
};

// Conversations per hour of the day, all weekdays together
export const hourlySeries = cells => {
  const totals = totalsBy(cells, 'hour');
  return Array.from({ length: 24 }, (_, hour) => totals[hour] || 0);
};

// Share of the period's conversations that ended a given way, capped at 100
export const outcomeRate = (source, key) =>
  source.conversations_count
    ? Math.min(
        Math.round((source[key] / source.conversations_count) * 100),
        100
      )
    : null;
