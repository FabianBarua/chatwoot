// Theme classes for @chatwoot/viz charts, matching the dashboard tokens in light and dark mode
export const BAR_CHART_CLASS =
  '[--cw-viz-bar-label-color:rgb(var(--slate-11))] [--cw-viz-bar-axis-color:rgb(var(--slate-4))] [--cw-viz-bar-zero-line-color:rgb(var(--slate-6))] [--cw-viz-bar-axis-font-size:0.75rem] [--cw-viz-bar-value-font-size:0.75rem] [--cw-viz-bar-value-color:rgb(var(--slate-11))] [--cw-viz-bar-tooltip-background:rgb(var(--solid-2))] [--cw-viz-bar-tooltip-color:rgb(var(--slate-12))] [--cw-viz-bar-tooltip-label-color:rgb(var(--slate-11))] [--cw-viz-bar-tooltip-border-color:rgb(var(--border-strong))]';

export const LINE_CHART_CLASS =
  '[--cw-viz-line-label-color:rgb(var(--slate-11))] [--cw-viz-line-axis-color:rgb(var(--slate-4))] [--cw-viz-line-axis-font-size:0.75rem] [--cw-viz-line-value-font-size:0.75rem] [--cw-viz-line-width:0.125rem] [--cw-viz-line-point-border-width:0.25rem] [--cw-viz-line-tooltip-background:rgb(var(--solid-2))] [--cw-viz-line-tooltip-color:rgb(var(--slate-12))] [--cw-viz-line-tooltip-border-color:rgb(var(--border-strong))]';

export const HEATMAP_CLASS =
  '[--cw-viz-heatmap-level-0-color:rgb(var(--slate-2))] [--cw-viz-heatmap-cell-border-color:rgb(var(--border-strong))] [--cw-viz-heatmap-label-color:rgb(var(--slate-11))] [--cw-viz-heatmap-label-background:rgb(var(--solid-2))] [--cw-viz-heatmap-row-title-color:rgb(var(--slate-12))] [--cw-viz-heatmap-column-label-color:rgb(var(--slate-11))] [--cw-viz-heatmap-tooltip-border-color:rgb(var(--border-strong))] [--cw-viz-heatmap-tooltip-color:rgb(var(--slate-12))] [--cw-viz-heatmap-tooltip-background:rgb(var(--solid-2))] [--cw-viz-heatmap-tooltip-label-color:rgb(var(--slate-11))] [--cw-viz-heatmap-focus-color:rgb(var(--blue-9))]';

export const DONUT_CHART_CLASS =
  '[--cw-viz-donut-remainder-color:rgb(var(--slate-3))] [--cw-viz-donut-label-color:rgb(var(--slate-11))] [--cw-viz-donut-tooltip-background:rgb(var(--solid-2))] [--cw-viz-donut-tooltip-color:rgb(var(--slate-12))] [--cw-viz-donut-tooltip-border-color:rgb(var(--border-strong))]';

export const COLORS = {
  online: 'rgb(var(--teal-9))',
  busy: 'rgb(var(--amber-9))',
  offline: 'rgb(var(--slate-7))',
  primary: 'rgb(var(--blue-9))',
  secondary: 'rgb(var(--iris-9))',
  muted: 'rgb(var(--slate-7))',
};

export const HEATMAP_COLORS = [
  'rgb(var(--blue-3))',
  'rgb(var(--blue-5))',
  'rgb(var(--blue-7))',
  'rgb(var(--blue-8))',
  'rgb(var(--blue-9))',
  'rgb(var(--blue-10))',
  'rgb(var(--blue-11))',
];

export const HEATMAP_QUANTILES = [0.2, 0.4, 0.6, 0.8, 0.9, 0.99];

export const STATUS_DOT_CLASSES = {
  online: 'bg-n-teal-9',
  busy: 'bg-n-amber-9',
  offline: 'bg-n-slate-8',
};

export const toHours = seconds => Math.round(((seconds || 0) / 3600) * 10) / 10;

export const formatHours = value => `${Number(value || 0).toLocaleString()} h`;

export const formatCount = value =>
  value || value === 0 ? Number(value).toLocaleString() : '--';

// Compact duration that reads the same in every language: 45s, 9m 54s, 3h 20m, 2d 4h
export const formatShortDuration = seconds => {
  const total = Math.round(seconds || 0);
  if (total < 60) return `${total}s`;
  const days = Math.floor(total / 86400);
  const hours = Math.floor((total % 86400) / 3600);
  const minutes = Math.floor((total % 3600) / 60);
  if (days) return hours ? `${days}d ${hours}h` : `${days}d`;
  if (hours) return minutes ? `${hours}h ${minutes}m` : `${hours}h`;
  const rest = total % 60;
  return rest ? `${minutes}m ${rest}s` : `${minutes}m`;
};

export const formatDuration = seconds =>
  seconds ? formatShortDuration(seconds) : '--';

export const COVERAGE_COLORS = [
  'rgb(var(--teal-3))',
  'rgb(var(--teal-5))',
  'rgb(var(--teal-7))',
  'rgb(var(--teal-8))',
  'rgb(var(--teal-9))',
  'rgb(var(--teal-10))',
  'rgb(var(--teal-11))',
];

export const formatAgents = value => Number(value || 0).toLocaleString();
