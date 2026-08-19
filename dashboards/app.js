'use strict';

const CARDS = [
  { key: 'version', label: 'version' },
  { key: 'mode', label: 'mode' },
  { key: 'running', label: 'running' },
  { key: 'battery_percentage', label: 'battery', suffix: '%' },
  { key: 'uptime_seconds', label: 'uptime', format: formatUptime },
  { key: 'free_bytes', label: 'free storage', format: formatBytes },
  { key: 'hostname', label: 'hostname' },
];

function formatUptime(seconds) {
  const value = Number(seconds);
  if (!Number.isFinite(value)) {
    return '—';
  }
  const hours = Math.floor(value / 3600);
  const minutes = Math.floor((value % 3600) / 60);
  return `${hours}h ${minutes}m`;
}

function formatBytes(bytes) {
  const value = Number(bytes);
  if (!Number.isFinite(value)) {
    return '—';
  }
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  let size = value;
  let unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit += 1;
  }
  return `${size.toFixed(1)} ${units[unit]}`;
}

function render(status) {
  const container = document.getElementById('cards');
  container.textContent = '';

  for (const card of CARDS) {
    const raw = status[card.key];
    let text;
    if (raw === undefined || raw === null || raw === '') {
      text = '—';
    } else if (card.format) {
      text = card.format(raw);
    } else {
      text = `${raw}${card.suffix || ''}`;
    }

    const box = document.createElement('div');
    box.className = 'card';

    const label = document.createElement('div');
    label.className = 'label';
    label.textContent = card.label;

    const value = document.createElement('div');
    value.className = 'value';
    value.textContent = text;

    box.append(label, value);
    container.append(box);
  }

  const footer = document.getElementById('footer');
  footer.className = '';
  footer.textContent = `updated at ${status.updated_at || 'unknown'}`;
}

async function refresh() {
  try {
    const response = await fetch('status.json', { cache: 'no-store' });
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
    render(await response.json());
  } catch (error) {
    const footer = document.getElementById('footer');
    footer.className = 'error';
    footer.textContent = `status unavailable: ${error.message}`;
  }
}

refresh();
setInterval(refresh, 10000);
