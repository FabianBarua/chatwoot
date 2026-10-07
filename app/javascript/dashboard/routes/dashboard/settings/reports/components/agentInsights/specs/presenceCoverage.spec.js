import { presenceCoverage } from '../presenceCoverage';

// Local times, so the expectations hold in any timezone
const at = (hour, minute = 0) =>
  new Date(2026, 9, 5, hour, minute).getTime() / 1000; // Monday 5 Oct 2026

const segment = (status, from, to) => ({ status, from, to });

describe('presenceCoverage', () => {
  it('counts agents connected at each hour, splitting segments at hour boundaries', () => {
    const rows = [
      { timeline: [segment('online', at(10), at(12, 30))] },
      { timeline: [segment('busy', at(11), at(12))] },
    ];

    const { byHour } = presenceCoverage(rows, 1);

    expect(byHour[9]).toBe(0);
    expect(byHour[10]).toBe(1);
    expect(byHour[11]).toBe(2);
    expect(byHour[12]).toBe(0.5);
    expect(byHour[13]).toBe(0);
  });

  it('ignores offline time', () => {
    const rows = [{ timeline: [segment('offline', at(8), at(18))] }];

    expect(presenceCoverage(rows, 1).byHour.every(value => value === 0)).toBe(
      true
    );
  });

  it('averages over the days of the period', () => {
    const rows = [{ timeline: [segment('online', at(9), at(10))] }];

    expect(presenceCoverage(rows, 2).byHour[9]).toBe(0.5);
  });

  it('places the time on the right weekday and hour', () => {
    const rows = [{ timeline: [segment('online', at(15), at(16))] }];

    const { byWeekdayHour } = presenceCoverage(rows, 7);

    expect(byWeekdayHour[1][15]).toBe(1); // Monday
    expect(byWeekdayHour[2][15]).toBe(0);
  });

  it('handles agents without status changes', () => {
    expect(presenceCoverage([{ timeline: [] }, {}], 3).byHour).toHaveLength(24);
  });
});
