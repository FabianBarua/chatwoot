import { busiest, hourlySeries, outcomeRate, totalsBy } from '../botSchedule';

const cells = [
  { weekday: 1, hour: 9, count: 3 },
  { weekday: 1, hour: 15, count: 2 },
  { weekday: 3, hour: 9, count: 4 },
];

describe('botSchedule', () => {
  it('sums the cells by weekday and by hour', () => {
    expect(totalsBy(cells, 'weekday')).toEqual({ 1: 5, 3: 4 });
    expect(totalsBy(cells, 'hour')).toEqual({ 9: 7, 15: 2 });
  });

  it('finds the busiest key', () => {
    expect(busiest(totalsBy(cells, 'weekday'))).toEqual({ key: 1, count: 5 });
    expect(busiest(totalsBy(cells, 'hour'))).toEqual({ key: 9, count: 7 });
    expect(busiest({})).toBeNull();
  });

  it('builds the 24 hour series', () => {
    const series = hourlySeries(cells);
    expect(series).toHaveLength(24);
    expect(series[9]).toBe(7);
    expect(series[15]).toBe(2);
    expect(series[0]).toBe(0);
  });

  it('computes outcome rates against the conversations of the period', () => {
    const summary = { conversations_count: 8, bot_resolved_count: 2 };
    expect(outcomeRate(summary, 'bot_resolved_count')).toBe(25);
    expect(outcomeRate({ conversations_count: 0 }, 'bot_resolved_count')).toBe(
      null
    );
    expect(
      outcomeRate({ conversations_count: 2, handoff_count: 5 }, 'handoff_count')
    ).toBe(100);
  });
});
