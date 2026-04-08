/* ═══════════════════════════════════════════════
   PlayPass — Super Admin Panel v2
   ═══════════════════════════════════════════════ */

const SUPABASE_URL = 'https://rizyqzjszaknzjboooow.supabase.co';
const SUPABASE_ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJpenlxempzemFrbnpqYm9vb293Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM4NjgzMzMsImV4cCI6MjA4OTQ0NDMzM30.cfptzTL4AkpN1xjGbIC4-yEjXVe8LPjdTNOzrYsykcs';

const sb = supabase.createClient(SUPABASE_URL, SUPABASE_ANON);

let currentAdmin = null;
let clubsCache = [];
let usersCache = [];
let usersCurrentPage = 1;
let usersTotalPages = 1;
const USERS_PER_PAGE = 20;
let logsCurrentPage = 1;
let logsTotalPages = 1;
const LOGS_PER_PAGE = 30;
let liveChannel = null;
let charts = {};
let yandexMap = null;
let mapPlacemarks = [];
let ticketsCache = [];
let bannersCache = [];
let selectedClubs = new Set();
let selectedUsers = new Set();
let selectedTickets = new Set();
let currentLang = localStorage.getItem('lang') || 'ru';

/* ── HELPERS ─────────────────────────────────── */
const $ = (id) => document.getElementById(id);
const fmt = (n) => Number(n || 0).toLocaleString('ru-RU');
const fmtDate = (d) => d ? new Date(d).toLocaleDateString('ru-RU', { day: '2-digit', month: '2-digit', year: 'numeric' }) : '—';
const fmtDateTime = (d) => d ? new Date(d).toLocaleString('ru-RU', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '—';

/* ── i18n ────────────────────────────────────── */
function t(key) { return (LANG[currentLang] && LANG[currentLang][key]) || (LANG.ru[key]) || key; }

function applyLanguage() {
  document.querySelectorAll('[data-i18n]').forEach(el => {
    const key = el.getAttribute('data-i18n');
    const val = t(key);
    if (val) el.textContent = val;
  });
  document.querySelectorAll('[data-i18n-ph]').forEach(el => {
    const key = el.getAttribute('data-i18n-ph');
    const val = t(key);
    if (val) el.placeholder = val;
  });
  document.querySelectorAll('[data-i18n-title]').forEach(el => {
    const key = el.getAttribute('data-i18n-title');
    const val = t(key);
    if (val) el.title = val;
  });
  // update toggle button label
  const langLabel = $('lang-label');
  if (langLabel) langLabel.textContent = currentLang === 'ru' ? 'UZ' : 'RU';
}

function toggleLang() {
  currentLang = currentLang === 'ru' ? 'uz' : 'ru';
  localStorage.setItem('lang', currentLang);
  applyLanguage();
}

/* ── THEME ───────────────────────────────────── */
function initTheme() {
  const saved = localStorage.getItem('theme') || 'dark';
  document.documentElement.dataset.theme = saved;
  const icon = $('theme-icon');
  if (icon) icon.textContent = saved === 'dark' ? '☀' : '🌙';
}

function toggleTheme() {
  const current = document.documentElement.dataset.theme || 'dark';
  const next = current === 'dark' ? 'light' : 'dark';
  document.documentElement.dataset.theme = next;
  localStorage.setItem('theme', next);
  const icon = $('theme-icon');
  if (icon) icon.textContent = next === 'dark' ? '☀' : '🌙';
  // Re-render visible charts with updated grid/tick colors
  recolorCharts();
}

function recolorCharts() {
  const isLight = document.documentElement.dataset.theme === 'light';
  const gridColor = isLight ? 'rgba(0,0,0,0.08)' : 'rgba(255,255,255,0.15)';
  const tickColor = isLight ? '#9CA3AF' : '#9CA3AF';
  Object.values(charts).forEach(chart => {
    if (!chart || !chart.options || !chart.options.scales) return;
    ['x', 'y'].forEach(axis => {
      if (chart.options.scales[axis]) {
        chart.options.scales[axis].grid.color = gridColor;
        chart.options.scales[axis].ticks.color = tickColor;
      }
    });
    chart.update('none');
  });
}

const timeAgo = (d) => {
  const diff = (Date.now() - new Date(d).getTime()) / 1000;
  if (diff < 60) return t('dash_just_now');
  if (diff < 3600) return `${Math.floor(diff / 60)} ${t('dash_min_ago')}`;
  if (diff < 86400) return `${Math.floor(diff / 3600)} ${t('dash_hr_ago')}`;
  return fmtDate(d);
};

function showToast(message, type = 'success') {
  const existing = document.querySelector('.toast');
  if (existing) existing.remove();
  const toast = document.createElement('div');
  toast.className = `toast toast-${type}`;
  toast.textContent = message;
  document.body.appendChild(toast);
  setTimeout(() => toast.remove(), 3500);
}

function esc(str) {
  if (!str) return '';
  const div = document.createElement('div');
  div.textContent = String(str);
  return div.innerHTML;
}

function escAttr(s) { return String(s).replace(/['"<>&]/g, c => ({'\'':'&#39;','"':'&quot;','<':'&lt;','>':'&gt;','&':'&amp;'})[c]); }

function toDateInput(d) {
  return d.toISOString().split('T')[0];
}

/* ── ADMIN LOG HELPER ────────────────────────── */
async function logAction(action, entityType, entityId, details) {
  try {
    await sb.from('admin_logs').insert({
      admin_id: currentAdmin?.id,
      admin_name: currentAdmin?.name || currentAdmin?.email,
      action,
      entity_type: entityType || null,
      entity_id: entityId || null,
      details: details || null,
    });
  } catch (e) { console.warn('logAction failed:', e); }
}

/* ── CSV EXPORT HELPER ───────────────────────── */
function downloadCSV(filename, headers, rows) {
  const bom = '\uFEFF';
  const csv = bom + [headers.join(';'), ...rows.map(r => r.map(c => `"${String(c ?? '').replace(/"/g, '""')}"`).join(';'))].join('\n');
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
  const link = document.createElement('a');
  link.href = URL.createObjectURL(blob);
  link.download = filename;
  link.click();
  URL.revokeObjectURL(link.href);
}

/* ── AUTH ─────────────────────────────────────── */
async function handleLogin() {
  const email = $('login-email').value.trim();
  const password = $('login-password').value;
  const errEl = $('login-error');
  errEl.classList.add('hidden');

  if (!email || !password) { errEl.textContent = 'Введите email и пароль'; errEl.classList.remove('hidden'); return; }

  try {
    const { data, error } = await sb.auth.signInWithPassword({ email, password });
    if (error) throw error;

    const { data: admin, error: aErr } = await sb.from('admin_users').select('*').eq('id', data.user.id).single();
    if (aErr || !admin || admin.role !== 'superadmin') {
      await sb.auth.signOut();
      errEl.textContent = 'Доступ запрещён. Только для суперадминов.';
      errEl.classList.remove('hidden');
      return;
    }

    currentAdmin = admin;
    $('admin-name').textContent = admin.name || email;
    showApp();
  } catch (e) {
    errEl.textContent = e.message || 'Ошибка входа';
    errEl.classList.remove('hidden');
  }
}

function handleLogout() {
  sb.auth.signOut();
  currentAdmin = null;
  if (liveChannel) { sb.removeChannel(liveChannel); liveChannel = null; }
  $('app-page').classList.add('hidden');
  $('login-page').classList.remove('hidden');
}

async function checkSession() {
  const { data: { session } } = await sb.auth.getSession();
  if (!session) return;
  const { data: admin } = await sb.from('admin_users').select('*').eq('id', session.user.id).single();
  if (admin && admin.role === 'superadmin') {
    currentAdmin = admin;
    $('admin-name').textContent = admin.name || session.user.email;
    showApp();
  }
}

function showApp() {
  $('login-page').classList.add('hidden');
  $('app-page').classList.remove('hidden');
  loadDashboard();
  startLiveVisits();
}

/* ── TAB NAVIGATION ──────────────────────────── */
function showTab(tab, el) {
  document.querySelectorAll('.tab-content').forEach(t => t.classList.add('hidden'));
  document.querySelectorAll('.nav-item').forEach(n => n.classList.remove('active'));
  $('tab-' + tab).classList.remove('hidden');
  if (el) {
    el.classList.add('active');
    // auto-open parent group
    const group = el.closest('.nav-group');
    if (group && !group.classList.contains('open')) group.classList.add('open');
  }

  const loaders = {
    dashboard: loadDashboard, clubs: loadClubs, users: loadUsers,
    payments: loadPayments, reviews: loadReviews, gifts: loadGifts,
    promos: loadPromos, notifications: loadNotifHistory, logs: loadLogs,
    map: loadMap, tickets: loadTickets,
    banners: loadBanners, finance: loadFinance,
    bookings: loadAllBookings,
  };
  if (loaders[tab]) loaders[tab]();
}

function toggleNavGroup(header) {
  header.parentElement.classList.toggle('open');
}

/* ═══════════════════════════════════════════════
   1. DASHBOARD + CHARTS
   ═══════════════════════════════════════════════ */
async function loadDashboard() {
  try {
    const startOfMonth = new Date(); startOfMonth.setDate(1); startOfMonth.setHours(0,0,0,0);
    const today = new Date(); today.setHours(0,0,0,0);

    // All 6 stat queries in parallel
    const [rUsers, rSubs, rPayments, rVisits, rClubs, rPending] = await Promise.all([
      sb.from('users').select('*', { count: 'exact', head: true }),
      sb.from('subscriptions').select('*', { count: 'exact', head: true }).eq('status', 'active'),
      sb.from('subscription_requests').select('amount_uzs').eq('status', 'approved').gte('created_at', startOfMonth.toISOString()),
      sb.from('visits').select('*', { count: 'exact', head: true }).gte('created_at', today.toISOString()),
      sb.from('clubs').select('*', { count: 'exact', head: true }),
      sb.from('subscription_requests').select('*', { count: 'exact', head: true }).eq('status', 'pending'),
    ]);

    const userCount = rUsers.count, subCount = rSubs.count;
    $('s-users').textContent = fmt(userCount);
    $('s-subs').textContent = fmt(subCount);
    $('s-revenue').textContent = fmt((rPayments.data || []).reduce((s, p) => s + (p.amount_uzs || 0), 0));
    $('s-today').textContent = fmt(rVisits.count);
    $('s-clubs').textContent = fmt(rClubs.count);
    $('s-pending').textContent = fmt(rPending.count);

    await Promise.all([loadRecentVisits(), loadCharts(userCount, subCount)]);
  } catch (e) { console.error('Dashboard error:', e); }
}

async function loadCharts(totalUsers, activeSubs) {
  const thirtyDaysAgo = new Date(); thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
  const iso30 = thirtyDaysAgo.toISOString();

  // All 4 chart queries in parallel
  const [rRev, rUsers, rVisits, rFunnel] = await Promise.all([
    sb.from('subscription_requests').select('amount_uzs, created_at').eq('status', 'approved').gte('created_at', iso30),
    sb.from('users').select('created_at').gte('created_at', iso30),
    sb.from('visits').select('club_id, clubs(name)').gte('created_at', iso30),
    sb.from('visits').select('user_id', { count: 'exact', head: true }).gte('created_at', iso30),
  ]);

  // Revenue chart
  const revByDay = {};
  (rRev.data || []).forEach(p => { const d = p.created_at?.substring(0, 10); revByDay[d] = (revByDay[d] || 0) + (p.amount_uzs || 0); });
  const revLabels = [], revValues = [];
  for (let i = 29; i >= 0; i--) { const d = new Date(); d.setDate(d.getDate() - i); const key = d.toISOString().substring(0, 10); revLabels.push(key.substring(5)); revValues.push(revByDay[key] || 0); }
  renderChart('chart-revenue', 'bar', revLabels, revValues, t('dash_revenue_label'), '#6366F1');

  // Users chart
  const userByDay = {};
  (rUsers.data || []).forEach(u => { const d = u.created_at?.substring(0, 10); userByDay[d] = (userByDay[d] || 0) + 1; });
  const userLabels = [], userValues = [];
  for (let i = 29; i >= 0; i--) { const d = new Date(); d.setDate(d.getDate() - i); const key = d.toISOString().substring(0, 10); userLabels.push(key.substring(5)); userValues.push(userByDay[key] || 0); }
  renderChart('chart-users', 'line', userLabels, userValues, t('dash_new_label'), '#10B981');

  // Top clubs
  const clubVisits = {};
  (rVisits.data || []).forEach(v => { const name = v.clubs?.name || v.club_id; clubVisits[name] = (clubVisits[name] || 0) + 1; });
  const sorted = Object.entries(clubVisits).sort((a, b) => b[1] - a[1]).slice(0, 10);
  renderChart('chart-top-clubs', 'bar', sorted.map(s => s[0]), sorted.map(s => s[1]), t('dash_visits_label'), '#F59E0B', true);

  // Funnel
  renderChart('chart-funnel', 'bar',
    [t('dash_funnel_reg'), t('dash_funnel_sub'), t('dash_funnel_vis')],
    [totalUsers || 0, activeSubs || 0, rFunnel.count || 0],
    t('dash_funnel_users'), ['#6366F1', '#10B981', '#F59E0B']
  );
}

function renderChart(canvasId, type, labels, data, label, color, horizontal = false) {
  if (charts[canvasId]) charts[canvasId].destroy();
  const ctx = $(canvasId);
  if (!ctx) return;

  const isLight = document.documentElement.dataset.theme === 'light';
  const gridColor = isLight ? 'rgba(0,0,0,0.08)' : 'rgba(255,255,255,0.15)';
  const tickColor = isLight ? '#9CA3AF' : '#9CA3AF';
  const isArrayColor = Array.isArray(color);
  charts[canvasId] = new Chart(ctx, {
    type,
    data: {
      labels,
      datasets: [{
        label,
        data,
        backgroundColor: isArrayColor ? color.map(c => c + 'BB') : (type === 'line' ? color + '22' : color + 'BB'),
        borderColor: isArrayColor ? color : color,
        borderWidth: type === 'line' ? 2.5 : 1,
        borderRadius: type === 'bar' ? 6 : 0,
        fill: type === 'line',
        tension: 0.3,
        pointRadius: type === 'line' ? 3 : 0,
        pointBackgroundColor: isArrayColor ? color[0] : color,
      }]
    },
    options: {
      indexAxis: horizontal ? 'y' : 'x',
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { display: false } },
      scales: {
        x: { grid: { color: gridColor }, ticks: { color: tickColor, font: { size: 10 }, maxRotation: 0 } },
        y: { grid: { color: gridColor }, ticks: { color: tickColor, font: { size: 10 } }, beginAtZero: true },
      }
    }
  });
}

async function loadRecentVisits() {
  const { data: visits } = await sb.from('visits').select('*, users(name), clubs(name)').order('created_at', { ascending: false }).limit(15);
  const container = $('live-visits');
  if (!visits || visits.length === 0) { container.innerHTML = '<div class="empty-state">Нет визитов</div>'; return; }
  container.innerHTML = visits.map(v => `
    <div class="live-visit-row">
      <div class="visit-avatar">●</div>
      <div><div class="visit-name">${esc(v.users?.name || 'Пользователь')}</div><div class="visit-club">${esc(v.clubs?.name || '—')}</div></div>
      <div class="visit-badge">${timeAgo(v.created_at)}</div>
    </div>`).join('');
}

function startLiveVisits() {
  if (liveChannel) sb.removeChannel(liveChannel);
  liveChannel = sb.channel('superadmin-visits')
    .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'visits' }, () => {
      loadRecentVisits();
      const el = $('s-today');
      if (el && el.textContent !== '—') el.textContent = fmt(parseInt(el.textContent.replace(/\s/g, '')) + 1);
    }).subscribe((status) => {
      if (status === 'CHANNEL_ERROR') console.error('Live channel error');
    });
}

function exportDashboardCSV() {
  const rows = [
    ['Пользователей', $('s-users').textContent],
    ['Активных подписок', $('s-subs').textContent],
    ['Выручка (мес)', $('s-revenue').textContent],
    ['Визитов сегодня', $('s-today').textContent],
    ['Клубов', $('s-clubs').textContent],
    ['Ожидают оплаты', $('s-pending').textContent],
  ];
  downloadCSV('dashboard.csv', ['Метрика', 'Значение'], rows);
}

/* ═══════════════════════════════════════════════
   CLUBS
   ═══════════════════════════════════════════════ */
async function loadClubs() {
  const { data, error } = await sb.from('clubs').select('*').order('name');
  if (error) { console.error(error); return; }
  clubsCache = data || [];
  renderClubs(clubsCache);
}

function renderClubs(clubs) {
  const tbody = $('clubs-tbody');
  if (clubs.length === 0) { tbody.innerHTML = '<tr><td colspan="8" class="empty-cell">Нет клубов</td></tr>'; return; }
  tbody.innerHTML = clubs.map(c => {
    const isActive = c.status === 'active';
    const isPending = c.status === 'pending';
    const statusText = isPending ? '◔ На проверке' : isActive ? '● Активен' : '○ Приостановлен';
    const statusClass = isPending ? 'status-pending' : isActive ? 'status-active' : 'status-inactive';
    return `<tr>
      <td><input type="checkbox" class="club-cb" data-id="${c.id}" onchange="onClubSelect()" ${selectedClubs.has(c.id)?'checked':''}></td>
      <td><strong style="color:var(--text)">${esc(c.name)}</strong></td>
      <td class="text-truncate">${esc(c.address || '—')}</td>
      <td><span class="badge tier-${c.tier || 'basic'}">${esc((c.tier || 'basic').toUpperCase())}</span></td>
      <td>${c.pc_count || '—'}</td>
      <td>${c.rating ? Number(c.rating).toFixed(1) : '—'}</td>
      <td><span class="${statusClass}">${statusText}</span></td>
      <td>
        <button class="btn-small btn-edit" onclick="editClubModal('${escAttr(c.id)}')">✏️</button>
        <button class="btn-small btn-delete" onclick="toggleClubStatus('${escAttr(c.id)}', ${isActive})">${isActive ? '🔒' : '🔓'}</button>
        ${isPending ? `<button class="btn-small btn-approve" onclick="verifyClub('${escAttr(c.id)}')">Верифицировать</button>` : ''}
      </td>
    </tr>`;
  }).join('');
}

function filterClubs() {
  const q = $('clubs-search').value.toLowerCase();
  const status = $('clubs-status-filter')?.value || 'all';
  let filtered = clubsCache;
  if (status !== 'all') filtered = filtered.filter(c => c.status === status);
  if (q) filtered = filtered.filter(c => c.name.toLowerCase().includes(q) || (c.address || '').toLowerCase().includes(q));
  renderClubs(filtered);
}

function showAddClubModal() {
  $('modal-title').textContent = 'Добавить клуб';
  $('modal-body').innerHTML = clubFormHtml();
  openModal();
  initPhotoUploader([]);
}

function editClubModal(id) {
  const club = clubsCache.find(c => c.id === id);
  if (!club) return;
  $('modal-title').textContent = 'Редактировать клуб';
  $('modal-body').innerHTML = clubFormHtml(club);
  openModal();
  initPhotoUploader(club.photos || []);
}

/* ── PHOTO UPLOADER ────────────────────────────── */
let clubPhotos = []; // current photos (URLs)
let pendingUploads = []; // File objects to upload on save

function initPhotoUploader(existingPhotos) {
  clubPhotos = [...existingPhotos];
  pendingUploads = [];
  renderPhotoGrid();
  setupDropzone();
}

function renderPhotoGrid() {
  const grid = $('photo-grid');
  if (!grid) return;
  grid.innerHTML = clubPhotos.map((url, i) => `
    <div class="photo-item" draggable="true" data-index="${i}">
      <img src="${esc(url)}" alt="Photo ${i + 1}" />
      <div class="photo-overlay">
        <span class="photo-index">${i + 1}</span>
        <button class="photo-delete" onclick="removePhoto(${i})" title="Удалить">&times;</button>
      </div>
      ${i === 0 ? '<span class="photo-main-badge">Главное</span>' : ''}
    </div>
  `).join('') + (pendingUploads.length > 0 ? pendingUploads.map((f, i) => `
    <div class="photo-item photo-pending">
      <img src="${URL.createObjectURL(f)}" alt="New ${i + 1}" />
      <div class="photo-overlay">
        <span class="photo-index" style="background:var(--warning)">+</span>
        <button class="photo-delete" onclick="removePendingPhoto(${i})" title="Убрать">&times;</button>
      </div>
    </div>
  `).join('') : '');

  const total = clubPhotos.length + pendingUploads.length;
  const counter = $('photo-counter');
  if (counter) counter.textContent = `${total}/5`;
  const addBtn = $('photo-add-area');
  if (addBtn) addBtn.style.display = total >= 5 ? 'none' : '';

  // Drag & drop reorder
  grid.querySelectorAll('.photo-item[draggable="true"]').forEach(item => {
    item.addEventListener('dragstart', (e) => {
      e.dataTransfer.setData('text/plain', item.dataset.index);
      item.classList.add('dragging');
    });
    item.addEventListener('dragend', () => item.classList.remove('dragging'));
    item.addEventListener('dragover', (e) => { e.preventDefault(); item.classList.add('drag-over'); });
    item.addEventListener('dragleave', () => item.classList.remove('drag-over'));
    item.addEventListener('drop', (e) => {
      e.preventDefault();
      item.classList.remove('drag-over');
      const from = parseInt(e.dataTransfer.getData('text/plain'));
      const to = parseInt(item.dataset.index);
      if (from !== to && !isNaN(from) && !isNaN(to)) {
        const moved = clubPhotos.splice(from, 1)[0];
        clubPhotos.splice(to, 0, moved);
        renderPhotoGrid();
      }
    });
  });
}

function setupDropzone() {
  const zone = $('photo-dropzone');
  if (!zone) return;
  zone.addEventListener('dragover', (e) => { e.preventDefault(); zone.classList.add('drag-active'); });
  zone.addEventListener('dragleave', () => zone.classList.remove('drag-active'));
  zone.addEventListener('drop', (e) => {
    e.preventDefault();
    zone.classList.remove('drag-active');
    handlePhotoFiles(e.dataTransfer.files);
  });
}

function triggerPhotoInput() {
  const inp = $('photo-file-input');
  if (inp) inp.click();
}

function onPhotoInputChange(input) {
  handlePhotoFiles(input.files);
  input.value = '';
}

function handlePhotoFiles(fileList) {
  const total = clubPhotos.length + pendingUploads.length;
  const remaining = 5 - total;
  if (remaining <= 0) { showToast('Максимум 5 фото', 'error'); return; }
  const files = Array.from(fileList).filter(f => f.type.startsWith('image/')).slice(0, remaining);
  if (files.length === 0) { showToast('Выберите изображения', 'error'); return; }
  // Validate size (max 5MB each)
  for (const f of files) {
    if (f.size > 5 * 1024 * 1024) { showToast(`${f.name} > 5MB`, 'error'); return; }
  }
  pendingUploads.push(...files);
  renderPhotoGrid();
}

function removePhoto(index) {
  clubPhotos.splice(index, 1);
  renderPhotoGrid();
}

function removePendingPhoto(index) {
  pendingUploads.splice(index, 1);
  renderPhotoGrid();
}

async function uploadClubPhotos(clubId) {
  const uploaded = [];
  for (const file of pendingUploads) {
    const ext = file.name.split('.').pop() || 'jpg';
    const path = `${clubId}/${Date.now()}_${Math.random().toString(36).slice(2, 8)}.${ext}`;
    const { error } = await sb.storage.from('club-photos').upload(path, file, {
      cacheControl: '3600', upsert: false,
    });
    if (error) { console.error('Upload error:', error); showToast(`Ошибка загрузки: ${file.name}`, 'error'); continue; }
    const { data: urlData } = sb.storage.from('club-photos').getPublicUrl(path);
    uploaded.push(urlData.publicUrl);
  }
  return uploaded;
}

async function deleteOldPhotos(oldPhotos, newPhotos) {
  // Delete from storage any photos that were removed
  const removed = oldPhotos.filter(u => !newPhotos.includes(u));
  for (const url of removed) {
    // Extract path from URL: ...club-photos/clubId/filename.jpg
    const match = url.match(/club-photos\/(.+)$/);
    if (match) {
      await sb.storage.from('club-photos').remove([match[1]]).catch(e => console.warn('Photo cleanup failed:', e));
    }
    // If it's an unsplash URL, just skip storage deletion
  }
}

const WEEK_DAYS = [
  { key: 'mon', ru: 'Пн', uz: 'Du' },
  { key: 'tue', ru: 'Вт', uz: 'Se' },
  { key: 'wed', ru: 'Ср', uz: 'Cho' },
  { key: 'thu', ru: 'Чт', uz: 'Pa' },
  { key: 'fri', ru: 'Пт', uz: 'Ju' },
  { key: 'sat', ru: 'Сб', uz: 'Sha' },
  { key: 'sun', ru: 'Вс', uz: 'Ya' },
];

function parseWorkingHours(wh) {
  if (typeof wh === 'object' && wh !== null && !Array.isArray(wh)) return wh;
  // default: all days 09:00-23:00
  const def = {};
  WEEK_DAYS.forEach(d => { def[d.key] = { open: '09:00', close: '23:00', closed: false }; });
  return def;
}

function workingHoursHtml(wh) {
  const hours = parseWorkingHours(wh);
  const is247 = wh && wh._247 === true;
  const closedLabel = currentLang === 'uz' ? 'Dam olish' : 'Выходной';
  const rows = WEEK_DAYS.map(d => {
    const h = hours[d.key] || { open: '09:00', close: '23:00', closed: false };
    const dayLabel = currentLang === 'uz' ? d.uz : d.ru;
    const dis = is247 || h.closed;
    return `<div class="wh-row">
      <span class="wh-day">${dayLabel}</span>
      <input type="text" class="wh-input" id="wh-${d.key}-open" value="${h.closed ? '' : (h.open || '09:00')}" placeholder="09:00" maxlength="5" ${dis ? 'disabled' : ''} />
      <span class="wh-sep">–</span>
      <input type="text" class="wh-input" id="wh-${d.key}-close" value="${h.closed ? '' : (h.close || '23:00')}" placeholder="23:00" maxlength="5" ${dis ? 'disabled' : ''} />
      <label class="wh-closed-label">${closedLabel} <input type="checkbox" id="wh-${d.key}-closed" ${h.closed ? 'checked' : ''} onchange="toggleDayClosed('${d.key}', this.checked)" ${is247 ? 'disabled' : ''} /></label>
    </div>`;
  }).join('');
  return rows + `<label class="wh-247-label"><span>24/7</span><input type="checkbox" id="wh-247" ${is247 ? 'checked' : ''} onchange="toggle247(this.checked)" /></label>`;
}

function toggle247(on) {
  WEEK_DAYS.forEach(d => {
    const o = $(`wh-${d.key}-open`), c = $(`wh-${d.key}-close`), cb = $(`wh-${d.key}-closed`);
    if (!o || !c || !cb) return;
    if (on) {
      o.value = '00:00'; o.disabled = true;
      c.value = '24:00'; c.disabled = true;
      cb.checked = false; cb.disabled = true;
    } else {
      o.value = '09:00'; o.disabled = false;
      c.value = '23:00'; c.disabled = false;
      cb.disabled = false;
    }
  });
}

function toggleDayClosed(dayKey, closed) {
  const openInput = $(`wh-${dayKey}-open`);
  const closeInput = $(`wh-${dayKey}-close`);
  if (!openInput || !closeInput) return;
  if (closed) {
    openInput.disabled = true; openInput.value = '';
    closeInput.disabled = true; closeInput.value = '';
  } else {
    openInput.disabled = false; openInput.value = '09:00';
    closeInput.disabled = false; closeInput.value = '23:00';
  }
}

function collectWorkingHours() {
  const is247 = $('wh-247')?.checked || false;
  if (is247) return { _247: true };
  const result = {};
  WEEK_DAYS.forEach(d => {
    const closed = $(`wh-${d.key}-closed`)?.checked || false;
    result[d.key] = closed
      ? { closed: true }
      : { open: $(`wh-${d.key}-open`)?.value || '09:00', close: $(`wh-${d.key}-close`)?.value || '23:00', closed: false };
  });
  return result;
}

function clubFormHtml(club = null) {
  return `
    <div class="form-group"><label>${t('clubs_label_name')}</label><input type="text" id="club-name" value="${esc(club?.name || '')}" placeholder="Cyber Arena" /></div>
    <div class="form-group"><label>${t('clubs_label_addr')}</label><input type="text" id="club-address" value="${esc(club?.address || '')}" placeholder="ул. Навои 45" /></div>
    <div class="form-group"><label>${t('clubs_label_tier')}</label><select id="club-tier">
      <option value="basic" ${club?.tier === 'basic' ? 'selected' : ''}>Basic</option>
      <option value="standard" ${club?.tier === 'standard' ? 'selected' : ''}>Standard</option>
      <option value="vip" ${club?.tier === 'vip' ? 'selected' : ''}>VIP</option>
    </select></div>
    <div class="form-group"><label>${t('clubs_label_pc')}</label><input type="number" id="club-pc" value="${club?.pc_count || ''}" placeholder="30" /></div>
    <div class="form-group"><label>${currentLang === 'uz' ? 'Umumiy sig\'im' : 'Общая вместимость'}</label><input type="number" id="club-capacity" value="${club?.total_capacity || ''}" placeholder="50" /></div>
    <div class="form-group">
      <label>${currentLang === 'uz' ? 'Suratlar' : 'Фотографии'} <span id="photo-counter" class="text-muted">${(club?.photos || []).length}/5</span></label>
      <div id="photo-dropzone" class="photo-dropzone">
        <div id="photo-grid" class="photo-grid"></div>
        <div id="photo-add-area" class="photo-add-area" onclick="triggerPhotoInput()">
          <div class="photo-add-btn">
            <span class="photo-add-icon">📷</span>
            <span>${currentLang === 'uz' ? 'Qo\'shish yoki tashlash' : 'Нажмите или перетащите'}</span>
          </div>
        </div>
        <input type="file" id="photo-file-input" accept="image/*" multiple hidden onchange="onPhotoInputChange(this)" />
      </div>
    </div>
    <div class="form-group">
      <label>${currentLang === 'uz' ? 'Ish vaqti' : 'Часы работы'}</label>
      <div class="wh-grid">${workingHoursHtml(club?.working_hours)}</div>
    </div>
    <div class="modal-actions">
      <button class="btn-secondary" onclick="closeModal()">${t('btn_cancel')}</button>
      <button class="btn-primary btn-inline" id="save-club-btn" onclick="saveClub('${escAttr(club?.id || '')}')">${club ? t('btn_save') : t('btn_add')}</button>
    </div>`;
}

async function saveClub(id) {
  const payload = {
    name: $('club-name').value.trim(), address: $('club-address').value.trim(), tier: $('club-tier').value,
    pc_count: parseInt($('club-pc').value) || null, total_capacity: parseInt($('club-capacity').value) || null,
    working_hours: collectWorkingHours(),
  };
  if (!payload.name) { showToast('Введите название клуба', 'error'); return; }

  const saveBtn = $('save-club-btn');
  if (saveBtn) { saveBtn.disabled = true; saveBtn.textContent = '⏳ Сохранение...'; }

  try {
    let clubId = id;

    // If new club — insert first to get ID for photo upload
    if (!clubId) {
      payload.status = 'active';
      payload.photos = [];
      const { data: inserted, error } = await sb.from('clubs').insert(payload).select('id').single();
      if (error) throw error;
      clubId = inserted.id;
    }

    // Upload new photos
    let newUrls = [];
    if (pendingUploads.length > 0) {
      if (saveBtn) saveBtn.textContent = '📷 Загрузка фото...';
      newUrls = await uploadClubPhotos(clubId);
    }

    // Build final photos array: existing (reordered) + newly uploaded
    const finalPhotos = [...clubPhotos, ...newUrls];

    // Delete removed photos from storage
    const oldClub = clubsCache.find(c => c.id === clubId);
    if (oldClub?.photos) {
      await deleteOldPhotos(oldClub.photos, finalPhotos);
    }

    // Update club with photos (and other fields if editing)
    if (id) {
      payload.photos = finalPhotos;
      const { error } = await sb.from('clubs').update(payload).eq('id', id);
      if (error) throw error;
      showToast('Клуб обновлён');
      logAction(t('log_club_updated'), 'club', id, payload.name);
    } else {
      // New club — just update photos
      const { error } = await sb.from('clubs').update({ photos: finalPhotos }).eq('id', clubId);
      if (error) throw error;
      showToast('Клуб добавлен');
      logAction(t('log_club_added'), 'club', clubId, payload.name);
    }

    pendingUploads = [];
    clubPhotos = [];
    closeModal(); loadClubs();
  } catch (e) {
    showToast(e.message, 'error');
  } finally {
    if (saveBtn) { saveBtn.disabled = false; saveBtn.textContent = id ? t('btn_save') : t('btn_add'); }
  }
}

async function toggleClubStatus(id, currentlyActive) {
  try {
    const newStatus = currentlyActive ? 'suspended' : 'active';
    const { error } = await sb.from('clubs').update({ status: newStatus }).eq('id', id);
    if (error) throw error;
    const club = clubsCache.find(c => c.id === id);
    showToast(currentlyActive ? 'Клуб приостановлен' : 'Клуб активирован');
    logAction(currentlyActive ? t('log_club_paused') : t('log_club_activated'), 'club', id, club?.name);
    loadClubs();
  } catch (e) { showToast(e.message, 'error'); }
}

function exportClubsCSV() {
  downloadCSV('clubs.csv', ['Название', 'Адрес', 'Tier', 'ПК', 'Рейтинг', 'Статус'],
    clubsCache.map(c => [c.name, c.address, c.tier, c.pc_count, c.rating, c.status]));
}

/* ═══════════════════════════════════════════════
   2. USERS + SUBSCRIPTION MANAGEMENT
   ═══════════════════════════════════════════════ */
async function loadUsers() {
  try {
    const from = (usersCurrentPage - 1) * USERS_PER_PAGE;
    const to = from + USERS_PER_PAGE - 1;
    const { data, error, count } = await sb.from('users').select('*, subscriptions(plan, status, end_date, hours_balance, hours_total)', { count: 'exact' }).order('created_at', { ascending: false }).range(from, to);
    if (error) throw error;
    usersCache = data || [];
    const totalPages = Math.ceil((count || 0) / USERS_PER_PAGE);
    usersTotalPages = totalPages || 1;
    renderUsers(usersCache);
    $('users-page-info').textContent = `${usersCurrentPage} / ${usersTotalPages}`;
    $('users-prev').disabled = usersCurrentPage <= 1;
    $('users-next').disabled = usersCurrentPage >= totalPages;
  } catch (e) { console.error(e); }
}

function renderUsers(users) {
  const tbody = $('users-tbody');
  if (users.length === 0) { tbody.innerHTML = '<tr><td colspan="8" class="empty-cell">Нет пользователей</td></tr>'; return; }
  tbody.innerHTML = users.map(u => {
    const sub = (u.subscriptions || []).find(s => s.status === 'active');
    const planBadge = sub ? `<span class="plan-badge plan-${sub.plan}">${sub.plan.toUpperCase()}</span>` : '<span class="badge badge-muted">Нет</span>';
    return `<tr>
      <td><input type="checkbox" class="user-cb" data-id="${u.id}" onchange="onUserSelect()" ${selectedUsers.has(u.id)?'checked':''}></td>
      <td><strong style="color:var(--text)">${esc(u.name || '—')}</strong></td>
      <td>${esc(u.phone || '—')}</td><td>${planBadge}</td><td>—</td>
      <td><span class="badge badge-primary">${esc(u.level || 'newbie')}</span></td>
      <td>${fmtDate(u.created_at)}</td>
      <td>
        <button class="btn-small btn-view" onclick="viewUserModal('${escAttr(u.id)}')">👤</button>
        <button class="btn-small btn-edit" onclick="manageSubModal('${escAttr(u.id)}')">📋</button>
      </td></tr>`;
  }).join('');
}

function usersPage(dir) { usersCurrentPage += dir; if (usersCurrentPage < 1) usersCurrentPage = 1; if (usersCurrentPage > usersTotalPages) usersCurrentPage = usersTotalPages; loadUsers(); }

function filterUsers() {
  const q = $('users-search').value.toLowerCase();
  if (!q) { renderUsers(usersCache); return; }
  renderUsers(usersCache.filter(u => (u.name || '').toLowerCase().includes(q) || (u.phone || '').toLowerCase().includes(q)));
}

async function viewUserModal(id) {
  const user = usersCache.find(u => u.id === id);
  if (!user) return;
  const { count: visitCount } = await sb.from('visits').select('*', { count: 'exact', head: true }).eq('user_id', id);
  const sub = (user.subscriptions || []).find(s => s.status === 'active');
  $('modal-title').textContent = user.name || 'Пользователь';
  $('modal-body').innerHTML = `
    <div class="user-detail-grid">
      <div class="user-detail-item"><label>Имя</label><span>${esc(user.name || '—')}</span></div>
      <div class="user-detail-item"><label>Телефон</label><span>${esc(user.phone || '—')}</span></div>
      <div class="user-detail-item"><label>Регистрация</label><span>${fmtDateTime(user.created_at)}</span></div>
      <div class="user-detail-item"><label>Визитов</label><span>${fmt(visitCount || 0)}</span></div>
      <div class="user-detail-item"><label>Подписка</label><span>${sub ? sub.plan.toUpperCase() + ' — до ' + fmtDate(sub.end_date) : 'Нет активной'}</span></div>
      <div class="user-detail-item"><label>Часов</label><span>${sub ? (sub.hours_balance === -1 ? '∞ Безлимит' : sub.hours_balance + ' / ' + sub.hours_total + ' ч') : '—'}</span></div>
      <div class="user-detail-item"><label>Уровень</label><span>${esc(user.level || 'newbie')}</span></div>
      <div class="user-detail-item"><label>Язык</label><span>${(user.preferred_language || 'ru').toUpperCase()}</span></div>
    </div>`;
  openModal();
}

async function manageSubModal(userId) {
  const user = usersCache.find(u => u.id === userId);
  if (!user) return;
  const sub = (user.subscriptions || []).find(s => s.status === 'active');

  $('modal-title').textContent = 'Управление подпиской — ' + (user.name || 'Пользователь');
  $('modal-body').innerHTML = `
    <div style="margin-bottom:20px">
      <strong>Текущая подписка:</strong> ${sub ? `${sub.plan.toUpperCase()} — до ${fmtDate(sub.end_date)}, часов: ${sub.hours_balance === -1 ? '∞' : sub.hours_balance}` : 'Нет активной подписки'}
    </div>
    ${sub ? `
      <div class="form-group"><label>Продлить на (дней)</label><input type="number" id="extend-days" value="30" min="1" /></div>
      <div class="form-group"><label>Добавить часов</label><input type="number" id="add-hours" value="0" min="0" /></div>
      <div class="modal-actions">
        <button class="btn-primary btn-inline" onclick="extendSubscription('${escAttr(userId)}', '${escAttr(sub.plan)}')">Продлить</button>
        <button class="btn-small btn-reject" style="padding:10px 16px" onclick="cancelSubscription('${escAttr(userId)}')">Отменить подписку</button>
      </div>
    ` : `
      <div class="form-group"><label>Назначить план</label><select id="assign-plan">
        <option value="basic">Basic (15ч)</option><option value="standard">Standard (30ч)</option>
        <option value="pro">Pro (безлимит)</option><option value="vip">VIP (безлимит)</option>
      </select></div>
      <div class="form-group"><label>Срок (дней)</label><input type="number" id="assign-days" value="30" min="1" /></div>
      <div class="modal-actions">
        <button class="btn-primary btn-inline" onclick="assignSubscription('${escAttr(userId)}')">Назначить</button>
      </div>
    `}`;
  openModal();
}

async function extendSubscription(userId, plan) {
  const days = parseInt($('extend-days')?.value) || 0;
  const hours = parseInt($('add-hours')?.value) || 0;
  if (days <= 0 && hours <= 0) { showToast('Введите дни или часы', 'error'); return; }
  try {
    const { data: subs } = await sb.from('subscriptions').select('*').eq('user_id', userId).eq('status', 'active').limit(1);
    const sub = subs?.[0];
    if (!sub) { showToast('Нет активной подписки', 'error'); return; }
    const updates = {};
    if (days > 0) {
      const newEnd = new Date(sub.end_date); newEnd.setDate(newEnd.getDate() + days);
      updates.end_date = newEnd.toISOString().split('T')[0];
    }
    if (hours > 0 && sub.hours_balance !== -1) {
      updates.hours_balance = sub.hours_balance + hours;
      updates.hours_total = sub.hours_total + hours;
    }
    const { error } = await sb.from('subscriptions').update(updates).eq('id', sub.id);
    if (error) throw error;
    showToast(`Подписка продлена: +${days} дн, +${hours} ч`);
    logAction(t('log_sub_extended'), 'user', userId, `+${days}д +${hours}ч`);
    closeModal(); loadUsers();
  } catch (e) { showToast(e.message, 'error'); }
}

async function cancelSubscription(userId) {
  if (!confirm('Отменить подписку?')) return;
  try {
    const { error } = await sb.from('subscriptions').update({ status: 'cancelled' }).eq('user_id', userId).eq('status', 'active');
    if (error) throw error;
    showToast('Подписка отменена');
    logAction(t('log_sub_cancelled'), 'user', userId);
    closeModal(); loadUsers();
  } catch (e) { showToast(e.message, 'error'); }
}

async function assignSubscription(userId) {
  const plan = $('assign-plan').value;
  const days = parseInt($('assign-days').value) || 30;
  const plans = { basic: { h: 15 }, standard: { h: 30 }, pro: { h: -1 }, vip: { h: -1 } };
  const p = plans[plan];
  const now = new Date(); const end = new Date(); end.setDate(end.getDate() + days);
  try {
    const { error } = await sb.from('subscriptions').insert({
      user_id: userId, plan, status: 'active',
      start_date: now.toISOString().split('T')[0], end_date: end.toISOString().split('T')[0],
      hours_total: p.h, hours_balance: p.h,
    });
    if (error) throw error;
    showToast(`Подписка ${plan.toUpperCase()} назначена`);
    logAction(t('log_sub_assigned'), 'user', userId, `${plan} на ${days} дн`);
    closeModal(); loadUsers();
  } catch (e) { showToast(e.message, 'error'); }
}

function exportUsersCSV() {
  downloadCSV('users.csv', ['Имя', 'Телефон', 'Подписка', 'Уровень', 'Регистрация'],
    usersCache.map(u => {
      const sub = (u.subscriptions || []).find(s => s.status === 'active');
      return [u.name, u.phone, sub ? sub.plan : 'нет', u.level, fmtDate(u.created_at)];
    }));
}

/* ═══════════════════════════════════════════════
   PAYMENTS
   ═══════════════════════════════════════════════ */
async function loadPayments() {
  try {
    const { data: pending } = await sb.from('subscription_requests').select('*, users(name, phone)').eq('status', 'pending').order('created_at', { ascending: false });
    renderPendingPayments(pending || []);
    const { data: done } = await sb.from('subscription_requests').select('*, users(name, phone)').in('status', ['approved', 'rejected']).order('processed_at', { ascending: false }).limit(50);
    renderDonePayments(done || []);
  } catch (e) { console.error(e); }
}

function renderPendingPayments(items) {
  const tbody = $('payments-pending-tbody');
  if (items.length === 0) { tbody.innerHTML = '<tr><td colspan="7" class="empty-cell">Нет ожидающих заявок</td></tr>'; return; }
  tbody.innerHTML = items.map(p => `<tr>
    <td>${fmtDateTime(p.created_at)}</td>
    <td><strong style="color:var(--text)">${esc(p.users?.name || '—')}</strong><div class="text-small">${esc(p.users?.phone || '')}</div></td>
    <td><span class="plan-badge plan-${p.plan || 'basic'}">${(p.plan || '—').toUpperCase()}</span></td>
    <td><strong>${fmt(p.amount_uzs)}</strong> UZS</td>
    <td>${esc(p.user_phone || '—')}</td>
    <td class="text-truncate">${esc(p.payment_note || '—')}</td>
    <td>
      <button class="btn-small btn-approve" onclick="approvePayment('${escAttr(p.id)}','${escAttr(p.user_id)}','${escAttr(p.plan)}',${p.amount_uzs || 0})">Принять</button>
      <button class="btn-small btn-reject" onclick="rejectPayment('${escAttr(p.id)}')">Отклонить</button>
    </td></tr>`).join('');
}

function renderDonePayments(items) {
  const tbody = $('payments-done-tbody');
  if (items.length === 0) { tbody.innerHTML = '<tr><td colspan="6" class="empty-cell">Нет обработанных</td></tr>'; return; }
  tbody.innerHTML = items.map(p => {
    const cls = p.status === 'approved' ? 'badge-success' : 'badge-error';
    const txt = p.status === 'approved' ? 'Одобрено' : 'Отклонено';
    return `<tr><td>${fmtDateTime(p.created_at)}</td>
      <td><strong style="color:var(--text)">${esc(p.users?.name || '—')}</strong></td>
      <td><span class="plan-badge plan-${p.plan || 'basic'}">${(p.plan || '—').toUpperCase()}</span></td>
      <td>${fmt(p.amount_uzs)} UZS</td>
      <td><span class="badge ${cls}">${txt}</span></td>
      <td>${fmtDateTime(p.processed_at)}</td></tr>`;
  }).join('');
}

async function approvePayment(reqId, userId, plan, amount) {
  try {
    const plans = { basic: { h: 15 }, standard: { h: 30 }, pro: { h: -1 }, vip: { h: -1 } };
    const p = plans[plan] || plans.basic;
    const end = new Date(); end.setDate(end.getDate() + 30);
    await sb.from('subscriptions').update({ status: 'expired' }).eq('user_id', userId).eq('status', 'active');
    const { error: subErr } = await sb.from('subscriptions').insert({
      user_id: userId, plan, status: 'active',
      start_date: new Date().toISOString().split('T')[0], end_date: end.toISOString().split('T')[0],
      hours_total: p.h, hours_balance: p.h, price_uzs: amount,
    });
    if (subErr) throw subErr;
    const { error: reqErr } = await sb.from('subscription_requests').update({ status: 'approved', processed_by: currentAdmin?.id, processed_at: new Date().toISOString() }).eq('id', reqId);
    if (reqErr) throw reqErr;
    showToast('Оплата одобрена');
    logAction(t('log_payment_approved'), 'payment', reqId, `${plan} — ${fmt(amount)} UZS`);
    loadPayments(); loadDashboard();
  } catch (e) { showToast(e.message, 'error'); }
}

async function rejectPayment(reqId) {
  try {
    const { error } = await sb.from('subscription_requests').update({ status: 'rejected', processed_by: currentAdmin?.id, processed_at: new Date().toISOString() }).eq('id', reqId);
    if (error) throw error;
    showToast('Заявка отклонена');
    logAction(t('log_payment_rejected'), 'payment', reqId);
    loadPayments();
  } catch (e) { showToast(e.message, 'error'); }
}

function exportPaymentsCSV() {
  // Re-fetch all approved for export
  sb.from('subscription_requests').select('*, users(name)').eq('status', 'approved').order('created_at', { ascending: false }).then(({ data }) => {
    downloadCSV('payments.csv', ['Дата', 'Пользователь', 'Тариф', 'Сумма'],
      (data || []).map(p => [fmtDateTime(p.created_at), p.users?.name, p.plan, p.amount_uzs]));
  }).catch(e => { showToast('Ошибка экспорта: ' + e.message, 'error'); });
}

/* ═══════════════════════════════════════════════
   4. PUSH NOTIFICATIONS
   ═══════════════════════════════════════════════ */
async function sendNotification() {
  const title = $('notif-title').value.trim();
  const body = $('notif-body').value.trim();
  const target = $('notif-target').value;
  if (!title || !body) { showToast('Заполните заголовок и текст', 'error'); return; }

  try {
    // Determine target user IDs
    let userIds = [];
    const targetLabels = { all: 'Все', active_sub: 'С подпиской', no_sub: 'Без подписки', expiring: 'Подписка истекает' };

    if (target === 'all') {
      const { data } = await sb.from('users').select('id');
      userIds = (data || []).map(u => u.id);
    } else if (target === 'active_sub') {
      const { data } = await sb.from('subscriptions').select('user_id').eq('status', 'active');
      userIds = [...new Set((data || []).map(s => s.user_id))];
    } else if (target === 'no_sub') {
      const { data: allUsers } = await sb.from('users').select('id');
      const { data: subs } = await sb.from('subscriptions').select('user_id').eq('status', 'active');
      const subIds = new Set((subs || []).map(s => s.user_id));
      userIds = (allUsers || []).filter(u => !subIds.has(u.id)).map(u => u.id);
    } else if (target === 'expiring') {
      const in7days = new Date(); in7days.setDate(in7days.getDate() + 7);
      const { data } = await sb.from('subscriptions').select('user_id').eq('status', 'active').lte('end_date', in7days.toISOString().split('T')[0]);
      userIds = [...new Set((data || []).map(s => s.user_id))];
    }

    if (userIds.length === 0) { showToast('Нет получателей в этом сегменте', 'error'); return; }

    // Insert notifications into notifications table
    const notifs = userIds.map(uid => ({ user_id: uid, title, body, type: 'push', event: 'admin_broadcast', is_read: false }));
    const { error } = await sb.from('notifications').insert(notifs);
    if (error) throw error;

    showToast(`Уведомление отправлено ${userIds.length} пользователям`);
    logAction(t('log_notif_sent'), 'notification', null, `"${title}" → ${targetLabels[target]} (${userIds.length})`);

    $('notif-title').value = '';
    $('notif-body').value = '';
    loadNotifHistory();
  } catch (e) { showToast(e.message, 'error'); }
}

async function loadNotifHistory() {
  try {
    const { data } = await sb.from('admin_logs').select('*').eq('entity_type', 'notification').order('created_at', { ascending: false }).limit(30);
    const tbody = $('notif-history-tbody');
    if (!data || data.length === 0) { tbody.innerHTML = '<tr><td colspan="5" class="empty-cell">Нет отправленных</td></tr>'; return; }
    tbody.innerHTML = data.map(l => {
      const parts = (l.details || '').match(/^"(.+?)" → (.+)$/);
      return `<tr>
        <td>${fmtDateTime(l.created_at)}</td>
        <td>${esc(parts?.[1] || '—')}</td>
        <td class="text-truncate">${esc(l.action)}</td>
        <td>${esc(parts?.[2] || '—')}</td>
        <td>—</td></tr>`;
    }).join('');
  } catch (e) { console.error(e); }
}

/* ═══════════════════════════════════════════════
   5. PROMO CODES
   ═══════════════════════════════════════════════ */
async function loadPromos() {
  try {
    const { data, error } = await sb.from('promo_codes').select('*').order('created_at', { ascending: false });
    if (error) throw error;
    renderPromos(data || []);
  } catch (e) {
    console.error(e);
    $('promos-tbody').innerHTML = `<tr><td colspan="8" class="empty-cell">Ошибка: ${esc(e.message)}</td></tr>`;
  }
}

function renderPromos(promos) {
  const tbody = $('promos-tbody');
  if (promos.length === 0) { tbody.innerHTML = '<tr><td colspan="8" class="empty-cell">Нет промокодов</td></tr>'; return; }
  tbody.innerHTML = promos.map(p => {
    const discountText = p.discount_type === 'percent' ? `${p.discount_value}%` : `${fmt(p.discount_value)} UZS`;
    const statusBadge = p.is_active ? '<span class="badge badge-success">Активен</span>' : '<span class="badge badge-muted">Неактивен</span>';
    return `<tr>
      <td><code style="color:var(--primary-light);font-size:13px">${esc(p.code)}</code></td>
      <td>${discountText}</td>
      <td>${p.used_count || 0}</td>
      <td>${p.max_uses || '∞'}</td>
      <td>${p.min_plan ? `<span class="plan-badge plan-${p.min_plan}">${p.min_plan.toUpperCase()}</span>` : 'Любой'}</td>
      <td>${p.expires_at ? fmtDate(p.expires_at) : 'Бессрочно'}</td>
      <td>${statusBadge}</td>
      <td>
        <button class="btn-small btn-delete" onclick="togglePromo('${escAttr(p.id)}', ${p.is_active})">${p.is_active ? 'Выкл' : 'Вкл'}</button>
      </td></tr>`;
  }).join('');
}

function showAddPromoModal() {
  $('modal-title').textContent = 'Создать промокод';
  $('modal-body').innerHTML = `
    <div class="form-group"><label>Код</label><input type="text" id="promo-code" placeholder="SUMMER2026" style="text-transform:uppercase" /></div>
    <div class="form-group"><label>Тип скидки</label><select id="promo-type">
      <option value="percent">Процент (%)</option><option value="fixed">Фиксированная (UZS)</option>
    </select></div>
    <div class="form-group"><label>Размер скидки</label><input type="number" id="promo-value" placeholder="20" min="1" /></div>
    <div class="form-group"><label>Макс. использований (пусто = безлимит)</label><input type="number" id="promo-max" placeholder="100" /></div>
    <div class="form-group"><label>Мин. план (необязательно)</label><select id="promo-plan">
      <option value="">Любой</option><option value="basic">Basic</option><option value="standard">Standard</option>
      <option value="pro">Pro</option><option value="vip">VIP</option>
    </select></div>
    <div class="form-group"><label>Истекает (необязательно)</label><input type="date" id="promo-expires" /></div>
    <div class="modal-actions">
      <button class="btn-secondary" onclick="closeModal()">Отмена</button>
      <button class="btn-primary btn-inline" onclick="savePromo()">Создать</button>
    </div>`;
  openModal();
}

async function savePromo() {
  const code = $('promo-code').value.trim().toUpperCase();
  const discountType = $('promo-type').value;
  const discountValue = parseInt($('promo-value').value);
  const maxUses = parseInt($('promo-max').value) || null;
  const minPlan = $('promo-plan').value || null;
  const expiresAt = $('promo-expires').value || null;

  if (!code || !discountValue) { showToast('Заполните код и размер скидки', 'error'); return; }

  try {
    const { error } = await sb.from('promo_codes').insert({
      code, discount_type: discountType, discount_value: discountValue,
      max_uses: maxUses, min_plan: minPlan,
      expires_at: expiresAt ? new Date(expiresAt).toISOString() : null,
      is_active: true, created_by: currentAdmin?.id,
    });
    if (error) throw error;
    showToast(`Промокод ${code} создан`);
    logAction(t('log_promo_created'), 'promo', null, `${code} — ${discountType === 'percent' ? discountValue + '%' : fmt(discountValue) + ' UZS'}`);
    closeModal(); loadPromos();
  } catch (e) { showToast(e.message, 'error'); }
}

async function togglePromo(id, isActive) {
  try {
    const { error } = await sb.from('promo_codes').update({ is_active: !isActive }).eq('id', id);
    if (error) throw error;
    showToast(isActive ? 'Промокод деактивирован' : 'Промокод активирован');
    logAction(isActive ? t('log_promo_deactivated') : t('log_promo_activated'), 'promo', id);
    loadPromos();
  } catch (e) { showToast(e.message, 'error'); }
}

function exportPromosCSV() {
  sb.from('promo_codes').select('*').order('created_at', { ascending: false }).then(({ data }) => {
    downloadCSV('promos.csv', ['Код', 'Тип', 'Скидка', 'Исп.', 'Макс', 'Активен', 'Истекает'],
      (data || []).map(p => [p.code, p.discount_type, p.discount_value, p.used_count, p.max_uses || '∞', p.is_active, fmtDate(p.expires_at)]));
  }).catch(e => { showToast('Ошибка экспорта: ' + e.message, 'error'); });
}

/* ═══════════════════════════════════════════════
   REVIEWS
   ═══════════════════════════════════════════════ */
async function loadReviews() {
  try {
    const { data, error } = await sb.from('reviews').select('*, users(name), clubs(name)').order('created_at', { ascending: false }).limit(100);
    if (error) {
      if (error.message?.includes('does not exist')) { $('reviews-tbody').innerHTML = '<tr><td colspan="6" class="empty-cell">Таблица ещё не создана</td></tr>'; return; }
      throw error;
    }
    renderReviews(data || []);
  } catch (e) { $('reviews-tbody').innerHTML = `<tr><td colspan="6" class="empty-cell">Ошибка: ${esc(e.message)}</td></tr>`; }
}

function renderReviews(reviews) {
  const tbody = $('reviews-tbody');
  if (reviews.length === 0) { tbody.innerHTML = '<tr><td colspan="6" class="empty-cell">Нет отзывов</td></tr>'; return; }
  tbody.innerHTML = reviews.map(r => {
    const photos = (r.photo_urls || []);
    const photosHtml = photos.length > 0
      ? `<div class="review-photos">${photos.map(url => `<a href="${esc(url)}" target="_blank"><img src="${esc(url)}" class="review-thumb" alt="фото" /></a>`).join('')}</div>`
      : '';
    return `<tr>
    <td>${fmtDate(r.created_at)}</td><td>${esc(r.users?.name || '—')}</td><td>${esc(r.clubs?.name || '—')}</td>
    <td><span class="stars">${'★'.repeat(r.rating || 0)}${'☆'.repeat(5 - (r.rating || 0))}</span></td>
    <td class="text-truncate">${esc(r.text || '—')}${photosHtml}</td>
    <td><button class="btn-small btn-delete" onclick="deleteReview('${escAttr(r.id)}')">Удалить</button></td></tr>`;
  }).join('');
}

async function deleteReview(id) {
  if (!confirm('Удалить отзыв?')) return;
  try {
    const { error } = await sb.from('reviews').delete().eq('id', id);
    if (error) throw error;
    showToast('Отзыв удалён');
    logAction(t('log_review_deleted'), 'review', id);
    loadReviews();
  } catch (e) { showToast(e.message, 'error'); }
}

/* ═══════════════════════════════════════════════
   GIFTS
   ═══════════════════════════════════════════════ */
async function loadGifts() {
  try {
    const { data, error } = await sb.from('gift_certificates').select('*').order('created_at', { ascending: false }).limit(100);
    if (error) throw error;
    renderGifts(data || []);
  } catch (e) { $('gifts-tbody').innerHTML = `<tr><td colspan="7" class="empty-cell">Ошибка: ${esc(e.message)}</td></tr>`; }
}

function renderGifts(gifts) {
  const tbody = $('gifts-tbody');
  if (gifts.length === 0) { tbody.innerHTML = '<tr><td colspan="7" class="empty-cell">Нет сертификатов</td></tr>'; return; }
  tbody.innerHTML = gifts.map(g => {
    const badge = g.redeemed_at ? '<span class="badge badge-success">Активирован</span>' : g.status === 'expired' ? '<span class="badge badge-muted">Истёк</span>' : '<span class="badge badge-warning">Ожидает</span>';
    return `<tr>
      <td><code style="color:var(--primary-light);font-size:13px">${esc(g.code || '—')}</code></td>
      <td><span class="plan-badge plan-${g.plan || 'basic'}">${(g.plan || '—').toUpperCase()}</span></td>
      <td>${fmt(g.amount_uzs)} UZS</td>
      <td>${esc(g.recipient_name || '—')}</td><td>${esc(g.recipient_phone || g.recipient_email || '—')}</td>
      <td>${badge}</td><td>${fmtDate(g.created_at)}</td></tr>`;
  }).join('');
}

/* ═══════════════════════════════════════════════
   6. ADMIN LOGS
   ═══════════════════════════════════════════════ */
async function loadLogs() {
  try {
    const from = (logsCurrentPage - 1) * LOGS_PER_PAGE;
    const to = from + LOGS_PER_PAGE - 1;
    const { data, error, count } = await sb.from('admin_logs').select('*', { count: 'exact' }).order('created_at', { ascending: false }).range(from, to);
    if (error) throw error;
    const totalPages = Math.ceil((count || 0) / LOGS_PER_PAGE);
    logsTotalPages = totalPages || 1;
    renderLogs(data || []);
    $('logs-page-info').textContent = `${logsCurrentPage} / ${logsTotalPages}`;
    $('logs-prev').disabled = logsCurrentPage <= 1;
    $('logs-next').disabled = logsCurrentPage >= totalPages;
  } catch (e) { console.error(e); }
}

function renderLogs(logs) {
  const tbody = $('logs-tbody');
  if (logs.length === 0) { tbody.innerHTML = '<tr><td colspan="5" class="empty-cell">Нет записей</td></tr>'; return; }
  tbody.innerHTML = logs.map(l => `<tr>
    <td>${fmtDateTime(l.created_at)}</td>
    <td>${esc(l.admin_name || '—')}</td>
    <td>${esc(l.action)}</td>
    <td><span class="badge badge-muted">${esc(l.entity_type || '—')}</span></td>
    <td class="text-truncate">${esc(l.details || '—')}</td></tr>`).join('');
}

function logsPage(dir) { logsCurrentPage += dir; if (logsCurrentPage < 1) logsCurrentPage = 1; if (logsCurrentPage > logsTotalPages) logsCurrentPage = logsTotalPages; loadLogs(); }

function exportLogsCSV() {
  sb.from('admin_logs').select('*').order('created_at', { ascending: false }).limit(500).then(({ data }) => {
    downloadCSV('admin_logs.csv', ['Дата', 'Админ', 'Действие', 'Тип', 'ID', 'Детали'],
      (data || []).map(l => [fmtDateTime(l.created_at), l.admin_name, l.action, l.entity_type, l.entity_id, l.details]));
  }).catch(e => { showToast('Ошибка экспорта: ' + e.message, 'error'); });
}

/* ═══════════════════════════════════════════════
   7. CLUB MAP (Yandex Maps)
   ═══════════════════════════════════════════════ */
const TASHKENT = [41.2995, 69.2401];
const MAP_COLORS = { active: '#10B981', suspended: '#EF4444', pending: '#F59E0B' };

let ymapsLoading = false;
function loadMap() {
  if (yandexMap) {
    yandexMap.container.fitToViewport();
    loadMapMarkers();
    return;
  }
  // Lazy-load Yandex Maps API on first use
  if (typeof ymaps === 'undefined') {
    if (ymapsLoading) return;
    ymapsLoading = true;
    const s = document.createElement('script');
    s.src = 'https://api-maps.yandex.ru/2.1/?lang=ru_RU';
    s.onload = () => loadMap();
    document.head.appendChild(s);
    return;
  }
  ymaps.ready(() => {
    yandexMap = new ymaps.Map('clubs-map', {
      center: TASHKENT,
      zoom: 12,
      controls: ['zoomControl'],
    }, {
      suppressMapOpenBlock: true,
    });
    loadMapMarkers();
  });
}

async function loadMapMarkers() {
  const { data: clubs } = await sb.from('clubs').select('*').order('name');
  if (!clubs || !yandexMap) return;
  // clear old placemarks
  mapPlacemarks.forEach(p => yandexMap.geoObjects.remove(p.placemark));
  mapPlacemarks = [];
  const hasCoords = clubs.some(c => c.geo_lat || c.latitude);
  clubs.forEach((c, i) => {
    let lat = c.geo_lat || c.latitude;
    let lon = c.geo_lon || c.longitude;
    if (!lat || !lon) {
      if (hasCoords) return;
      // demo coords
      lat = TASHKENT[0] + (Math.sin(i * 1.3) * 0.04) + (Math.random() * 0.02 - 0.01);
      lon = TASHKENT[1] + (Math.cos(i * 1.7) * 0.06) + (Math.random() * 0.02 - 0.01);
    }
    const color = MAP_COLORS[c.status] || '#6B7280';
    const pm = new ymaps.Placemark([lat, lon], {
      balloonContentHeader: `<span style="color:${color};font-weight:700">${esc(c.name)}</span>`,
      balloonContentBody: `
        <div style="font-size:13px;line-height:1.6">
          ${c.address ? esc(c.address) + '<br>' : ''}
          Tier: <b>${(c.tier || 'basic').toUpperCase()}</b> &nbsp;|&nbsp; ПК: <b>${c.pc_count || '?'}</b><br>
          Статус: <span style="color:${color};font-weight:600">${c.status}</span>
        </div>`,
      hintContent: esc(c.name),
    }, {
      preset: 'islands#circleDotIcon',
      iconColor: color,
    });
    yandexMap.geoObjects.add(pm);
    mapPlacemarks.push({ placemark: pm, club: c, lat, lon });
  });
}

/* ── MAP CLUB SEARCH ──────────────────────────── */
function filterMapClubs(query) {
  const box = $('map-search-results');
  if (!query.trim()) { box.classList.add('hidden'); return; }
  const q = query.toLowerCase();
  const matches = mapPlacemarks.filter(p =>
    p.club.name.toLowerCase().includes(q) ||
    (p.club.address || '').toLowerCase().includes(q)
  ).slice(0, 8);
  if (matches.length === 0) {
    box.innerHTML = '<div class="map-search-empty">Ничего не найдено</div>';
  } else {
    box.innerHTML = matches.map(m => {
      const color = MAP_COLORS[m.club.status] || '#6B7280';
      return `<div class="map-search-item" onclick="focusMapClub('${escAttr(m.club.id)}')">
        <span class="legend-dot" style="background:${color};flex-shrink:0"></span>
        <div>
          <div class="map-search-name">${esc(m.club.name)}</div>
          ${m.club.address ? `<div class="map-search-addr">${esc(m.club.address)}</div>` : ''}
        </div>
      </div>`;
    }).join('');
  }
  box.classList.remove('hidden');
}

function focusMapClub(clubId) {
  const entry = mapPlacemarks.find(p => p.club.id === clubId);
  if (!entry || !yandexMap) return;
  yandexMap.setCenter([entry.lat, entry.lon], 15, { duration: 300 });
  entry.placemark.balloon.open();
  $('map-search-results').classList.add('hidden');
  $('map-search').value = entry.club.name;
}

/* ═══════════════════════════════════════════════
   9. SUPPORT TICKETS
   ═══════════════════════════════════════════════ */
async function loadTickets() {
  try {
    const filter = $('tickets-filter')?.value || 'all';
    let q = sb.from('support_tickets').select('*, users(name, phone)').order('created_at', { ascending: false });
    if (filter !== 'all') q = q.eq('status', filter);
    const { data, error } = await q.limit(100);
    if (error) throw error;
    ticketsCache = data || [];
    renderTicketStats(ticketsCache);
    renderTickets(ticketsCache);
  } catch (e) {
    console.error(e);
    $('tickets-tbody').innerHTML = `<tr><td colspan="7" class="empty-cell">Ошибка: ${esc(e.message)}</td></tr>`;
  }
}

function renderTicketStats(tickets) {
  const stats = $('ticket-stats');
  if (!stats) return;
  const open = tickets.filter(t => t.status === 'open').length;
  const inProg = tickets.filter(t => t.status === 'in_progress').length;
  const resolved = tickets.filter(t => t.status === 'resolved').length;
  stats.innerHTML = `
    <div class="ticket-stat"><strong>${open}</strong> открытых</div>
    <div class="ticket-stat"><strong>${inProg}</strong> в работе</div>
    <div class="ticket-stat"><strong>${resolved}</strong> решённых</div>
    <div class="ticket-stat"><strong>${tickets.length}</strong> всего</div>`;
}

function renderTickets(tickets) {
  const tbody = $('tickets-tbody');
  if (tickets.length === 0) { tbody.innerHTML = '<tr><td colspan="7" class="empty-cell">Нет тикетов</td></tr>'; return; }
  const statusLabels = { open: 'Открыт', in_progress: 'В работе', resolved: 'Решён', closed: 'Закрыт' };
  const statusClasses = { open: 'badge-warning', in_progress: 'badge-primary', resolved: 'badge-success', closed: 'badge-muted' };
  tbody.innerHTML = tickets.map(t => `<tr>
    <td><input type="checkbox" class="ticket-cb" data-id="${t.id}" onchange="onTicketSelect()"></td>
    <td>${fmtDateTime(t.created_at)}</td>
    <td><strong style="color:var(--text)">${esc(t.users?.name || '—')}</strong><div class="text-small">${esc(t.users?.phone || '')}</div></td>
    <td class="text-truncate">${esc(t.subject)}</td>
    <td><span class="priority-${t.priority}">${t.priority === 'urgent' ? 'СРОЧНО' : t.priority === 'high' ? 'Высокий' : t.priority === 'normal' ? 'Обычный' : 'Низкий'}</span></td>
    <td><span class="badge ${statusClasses[t.status] || 'badge-muted'}">${statusLabels[t.status] || t.status}</span></td>
    <td><button class="btn-small btn-view" onclick="viewTicketModal('${escAttr(t.id)}')">Открыть</button></td>
  </tr>`).join('');
}

function filterTickets() {
  const q = $('tickets-search').value.toLowerCase();
  if (!q) { renderTickets(ticketsCache); return; }
  renderTickets(ticketsCache.filter(t =>
    (t.subject || '').toLowerCase().includes(q) || (t.users?.name || '').toLowerCase().includes(q)
  ));
}

async function viewTicketModal(id) {
  const t = ticketsCache.find(x => x.id === id);
  if (!t) return;
  $('modal-title').textContent = 'Тикет: ' + (t.subject || '');
  $('modal-body').innerHTML = `
    <div class="user-detail-grid">
      <div class="user-detail-item"><label>Пользователь</label><span>${esc(t.users?.name || '—')}</span></div>
      <div class="user-detail-item"><label>Дата</label><span>${fmtDateTime(t.created_at)}</span></div>
      <div class="user-detail-item"><label>Приоритет</label><span class="priority-${t.priority}">${t.priority}</span></div>
      <div class="user-detail-item"><label>Статус</label><span>${t.status}</span></div>
    </div>
    <div class="form-group" style="margin-top:16px"><label>Сообщение</label>
      <div style="background:var(--bg);padding:12px;border-radius:8px;color:var(--text-sec);font-size:13px">${esc(t.message)}</div>
    </div>
    ${t.admin_reply ? `<div class="form-group"><label>Ответ админа</label>
      <div style="background:var(--bg-surface);padding:12px;border-radius:8px;color:var(--success);font-size:13px">${esc(t.admin_reply)}</div>
    </div>` : ''}
    <div class="form-group"><label>Ваш ответ</label><textarea id="ticket-reply" placeholder="Напишите ответ...">${esc(t.admin_reply || '')}</textarea></div>
    <div class="form-group"><label>Статус</label><select id="ticket-status">
      <option value="open" ${t.status==='open'?'selected':''}>Открыт</option>
      <option value="in_progress" ${t.status==='in_progress'?'selected':''}>В работе</option>
      <option value="resolved" ${t.status==='resolved'?'selected':''}>Решён</option>
      <option value="closed" ${t.status==='closed'?'selected':''}>Закрыт</option>
    </select></div>
    <div class="modal-actions">
      <button class="btn-secondary" onclick="closeModal()">Отмена</button>
      <button class="btn-primary btn-inline" onclick="replyTicket('${escAttr(t.id)}')">Сохранить</button>
    </div>`;
  openModal();
}

async function replyTicket(id) {
  const reply = $('ticket-reply').value.trim();
  const status = $('ticket-status').value;
  try {
    const upd = { status, admin_reply: reply || null, replied_by: currentAdmin?.id, replied_at: new Date().toISOString() };
    const { error } = await sb.from('support_tickets').update(upd).eq('id', id);
    if (error) throw error;
    showToast('Тикет обновлён');
    logAction(t('log_ticket_replied'), 'ticket', id, status);
    closeModal(); loadTickets();
  } catch (e) { showToast(e.message, 'error'); }
}

function onTicketSelect() { /* placeholder for bulk select */ }

function exportTicketsCSV() {
  downloadCSV('tickets.csv', ['Дата', 'Пользователь', 'Тема', 'Приоритет', 'Статус', 'Ответ'],
    ticketsCache.map(t => [fmtDateTime(t.created_at), t.users?.name, t.subject, t.priority, t.status, t.admin_reply || '']));
}

/* ═══════════════════════════════════════════════
   10. CLUB VERIFICATION
   ═══════════════════════════════════════════════ */
async function verifyClub(id) {
  try {
    const { error } = await sb.from('clubs').update({ status: 'active' }).eq('id', id);
    if (error) throw error;
    const club = clubsCache.find(c => c.id === id);
    showToast('Клуб верифицирован и активирован');
    logAction(t('log_club_verified'), 'club', id, club?.name);
    loadClubs();
  } catch (e) { showToast(e.message, 'error'); }
}

/* ═══════════════════════════════════════════════
   11. BULK OPERATIONS
   ═══════════════════════════════════════════════ */
function onClubSelect() {
  selectedClubs.clear();
  document.querySelectorAll('.club-cb:checked').forEach(cb => selectedClubs.add(cb.dataset.id));
  const bar = $('clubs-bulk-actions');
  if (bar) bar.classList.toggle('hidden', selectedClubs.size === 0);
}

function toggleAllClubs(master) {
  document.querySelectorAll('.club-cb').forEach(cb => { cb.checked = master.checked; });
  onClubSelect();
}

async function bulkClubAction(newStatus) {
  if (selectedClubs.size === 0) return;
  if (!confirm(`Изменить статус ${selectedClubs.size} клубов на "${newStatus}"?`)) return;
  try {
    const ids = [...selectedClubs];
    const { error } = await sb.from('clubs').update({ status: newStatus }).in('id', ids);
    if (error) throw error;
    showToast(`${ids.length} клубов обновлено`);
    logAction(`${t('log_club_bulk')} → ${newStatus}`, 'club', null, `${ids.length} ${t('log_clubs_count')}`);
    selectedClubs.clear();
    loadClubs();
  } catch (e) { showToast(e.message, 'error'); }
}

function onUserSelect() {
  selectedUsers.clear();
  document.querySelectorAll('.user-cb:checked').forEach(cb => selectedUsers.add(cb.dataset.id));
  const bar = $('users-bulk-actions');
  if (bar) bar.classList.toggle('hidden', selectedUsers.size === 0);
}

function toggleAllUsers(master) {
  document.querySelectorAll('.user-cb').forEach(cb => { cb.checked = master.checked; });
  onUserSelect();
}

function toggleAllTickets(master) {
  document.querySelectorAll('.ticket-cb').forEach(cb => { cb.checked = master.checked; });
}

async function bulkSendNotification() {
  if (selectedUsers.size === 0) return;
  $('modal-title').textContent = 'Уведомить выбранных';
  $('modal-body').innerHTML = `
    <div class="form-group"><label>Заголовок</label><input type="text" id="bulk-notif-title" placeholder="Заголовок" /></div>
    <div class="form-group"><label>Текст</label><textarea id="bulk-notif-body" placeholder="Текст уведомления"></textarea></div>
    <div class="modal-actions">
      <button class="btn-secondary" onclick="closeModal()">Отмена</button>
      <button class="btn-primary btn-inline" onclick="sendBulkNotif()">Отправить (${selectedUsers.size})</button>
    </div>`;
  openModal();
}

async function sendBulkNotif() {
  const title = $('bulk-notif-title').value.trim();
  const body = $('bulk-notif-body').value.trim();
  if (!title || !body) { showToast('Заполните заголовок и текст', 'error'); return; }
  try {
    const notifs = [...selectedUsers].map(uid => ({ user_id: uid, title, body, type: 'push', event: 'admin_broadcast', is_read: false }));
    const { error } = await sb.from('notifications').insert(notifs);
    if (error) throw error;
    showToast(`Отправлено ${notifs.length} уведомлений`);
    logAction(t('log_notif_bulk'), 'notification', null, `"${title}" → ${notifs.length} ${t('log_users_count')}`);
    closeModal();
  } catch (e) { showToast(e.message, 'error'); }
}

function bulkExportSelected() {
  const selected = usersCache.filter(u => selectedUsers.has(u.id));
  if (selected.length === 0) return;
  downloadCSV('selected_users.csv', ['Имя', 'Телефон', 'Уровень', 'Регистрация'],
    selected.map(u => [u.name, u.phone, u.level, fmtDate(u.created_at)]));
}

/* ═══════════════════════════════════════════════
   12. BANNERS & NEWS CMS
   ═══════════════════════════════════════════════ */
async function loadBanners() {
  try {
    const typeFilter = $('banners-type-filter')?.value || 'all';
    let q = sb.from('banners').select('*').order('sort_order').order('created_at', { ascending: false });
    if (typeFilter !== 'all') q = q.eq('type', typeFilter);
    const { data, error } = await q;
    if (error) throw error;
    bannersCache = data || [];
    renderBanners(bannersCache);
  } catch (e) { $('banners-grid').innerHTML = `<div class="empty-state">Ошибка: ${esc(e.message)}</div>`; }
}

function renderBanners(banners) {
  const grid = $('banners-grid');
  if (banners.length === 0) { grid.innerHTML = '<div class="empty-state">Нет баннеров. Нажмите "+ Создать".</div>'; return; }
  const typeLabels = { banner: 'Баннер', news: 'Новость', promo: 'Акция' };
  grid.innerHTML = banners.map(b => `
    <div class="banner-card ${b.is_active ? '' : 'inactive'}">
      <div class="banner-card-image">
        ${b.image_url ? `<img src="${esc(b.image_url)}" alt="">` : typeLabels[b.type] || 'Banner'}
      </div>
      <div class="banner-card-body">
        <span class="banner-card-type type-${b.type}">${typeLabels[b.type] || b.type}</span>
        <div class="banner-card-title">${esc(b.title)}</div>
        <div class="banner-card-desc">${esc(b.description || '')}</div>
        <div class="banner-card-footer">
          <span class="banner-card-date">${fmtDate(b.created_at)}${b.ends_at ? ' — до ' + fmtDate(b.ends_at) : ''}</span>
          <div class="banner-card-actions">
            <button class="btn-small btn-edit" onclick="editBannerModal('${escAttr(b.id)}')">✏️</button>
            <button class="btn-small btn-delete" onclick="toggleBanner('${escAttr(b.id)}', ${b.is_active})">${b.is_active ? 'Скрыть' : 'Показать'}</button>
            <button class="btn-small btn-delete" onclick="deleteBanner('${escAttr(b.id)}')">X</button>
          </div>
        </div>
      </div>
    </div>
  `).join('');
}

function showAddBannerModal() {
  $('modal-title').textContent = 'Новый баннер';
  $('modal-body').innerHTML = bannerFormHtml();
  openModal();
}

function editBannerModal(id) {
  const b = bannersCache.find(x => x.id === id);
  if (!b) return;
  $('modal-title').textContent = 'Редактировать';
  $('modal-body').innerHTML = bannerFormHtml(b);
  openModal();
}

function bannerFormHtml(b = null) {
  return `
    <div class="form-group"><label>Заголовок</label><input type="text" id="banner-title" value="${esc(b?.title || '')}" placeholder="Новая акция!" /></div>
    <div class="form-group"><label>Описание</label><textarea id="banner-desc" placeholder="Описание...">${esc(b?.description || '')}</textarea></div>
    <div class="form-group"><label>URL картинки</label><input type="text" id="banner-image" value="${esc(b?.image_url || '')}" placeholder="https://..." /></div>
    <div class="form-group"><label>Ссылка (необязательно)</label><input type="text" id="banner-link" value="${esc(b?.action_url || '')}" placeholder="https://..." /></div>
    <div class="form-group"><label>Фон (HEX цвет)</label><input type="text" id="banner-bg" value="${esc(b?.bg_color || '')}" placeholder="#7C3AED" /></div>
    <div class="form-group"><label>Истекает</label><input type="date" id="banner-end" value="${b?.expires_at ? b.expires_at.substring(0,10) : ''}" /></div>
    <div class="form-group"><label>Порядок</label><input type="number" id="banner-sort" value="${b?.sort_order ?? 0}" /></div>
    <div class="modal-actions">
      <button class="btn-secondary" onclick="closeModal()">Отмена</button>
      <button class="btn-primary btn-inline" onclick="saveBanner('${escAttr(b?.id || '')}')">${b ? 'Сохранить' : 'Создать'}</button>
    </div>`;
}

async function saveBanner(id) {
  const payload = {
    title: $('banner-title').value.trim(),
    description: $('banner-desc').value.trim() || null,
    image_url: $('banner-image').value.trim() || null,
    action_url: $('banner-link').value.trim() || null,
    bg_color: $('banner-bg').value.trim() || null,
    expires_at: $('banner-end').value ? new Date($('banner-end').value).toISOString() : null,
    sort_order: parseInt($('banner-sort').value) || 0,
  };
  if (!payload.title) { showToast('Введите заголовок', 'error'); return; }
  try {
    if (id) {
      const { error } = await sb.from('banners').update(payload).eq('id', id);
      if (error) throw error;
      showToast('Баннер обновлён'); logAction(t('log_banner_updated'), 'banner', id, payload.title);
    } else {
      payload.is_active = true;
      const { error } = await sb.from('banners').insert(payload);
      if (error) throw error;
      showToast('Баннер создан'); logAction(t('log_banner_created'), 'banner', null, payload.title);
    }
    closeModal(); loadBanners();
  } catch (e) { showToast(e.message, 'error'); }
}

async function toggleBanner(id, isActive) {
  try {
    const { error } = await sb.from('banners').update({ is_active: !isActive }).eq('id', id);
    if (error) throw error;
    showToast(isActive ? 'Баннер скрыт' : 'Баннер показан');
    loadBanners();
  } catch (e) { showToast(e.message, 'error'); }
}

async function deleteBanner(id) {
  if (!confirm('Удалить баннер?')) return;
  try {
    const { error } = await sb.from('banners').delete().eq('id', id);
    if (error) throw error;
    showToast('Баннер удалён'); logAction(t('log_banner_deleted'), 'banner', id);
    loadBanners();
  } catch (e) { showToast(e.message, 'error'); }
}

/* ═══════════════════════════════════════════════
   BOOKINGS OVERVIEW (super-admin)
   ═══════════════════════════════════════════════ */
async function loadAllBookings() {
  try {
    const dateEl = $('bookings-date-filter');
    const statusEl = $('bookings-status-filter');
    if (!dateEl) return;
    if (!dateEl.value) dateEl.value = toDateInput(new Date());
    const date = dateEl.value;
    const statusFilter = statusEl.value;

    let query = sb.from('bookings')
      .select('*, clubs(name), users(name)')
      .eq('date', date)
      .order('start_time', { ascending: true });

    if (statusFilter) query = query.eq('status', statusFilter);

    const { data, error } = await query.limit(200);
    if (error) throw error;
    const bookings = data || [];

    // KPIs
    const total = bookings.length;
    const confirmed = bookings.filter(b => b.status === 'confirmed').length;
    const active = bookings.filter(b => b.status === 'active').length;
    const noShows = bookings.filter(b => b.status === 'no_show').length;
    const completed = bookings.filter(b => b.status === 'completed').length;

    $('bookings-kpis').innerHTML = `
      <div class="kpi-card"><div class="kpi-value">${total}</div><div class="kpi-label">Всего на дату</div></div>
      <div class="kpi-card"><div class="kpi-value" style="color:var(--primary)">${confirmed}</div><div class="kpi-label">Подтверждённые</div></div>
      <div class="kpi-card"><div class="kpi-value" style="color:var(--success)">${active + completed}</div><div class="kpi-label">Активные/готовые</div></div>
      <div class="kpi-card"><div class="kpi-value" style="color:var(--error)">${noShows}</div><div class="kpi-label">Неявки</div></div>
    `;

    // Table
    const tbody = $('all-bookings-tbody');
    if (!bookings.length) {
      tbody.innerHTML = '<tr><td colspan="7" class="empty-cell">Нет бронирований на эту дату</td></tr>';
      return;
    }

    tbody.innerHTML = bookings.map(b => {
      const clubName = b.clubs?.name || '—';
      const userName = b.users?.name || '—';
      const zone = b.zone || 'basic';
      const zoneLabel = zone === 'vip' ? 'VIP' : zone === 'pro' ? 'Про' : 'Базовая';
      const zoneColor = zone === 'vip' ? '#FBBF24' : zone === 'pro' ? '#A855F7' : '#10B981';

      let statusBadge = '';
      switch (b.status) {
        case 'confirmed': statusBadge = '<span class="badge">Подтверждён</span>'; break;
        case 'active': statusBadge = '<span class="badge badge-success">Активен</span>'; break;
        case 'completed': statusBadge = '<span class="badge badge-success">✓ Готово</span>'; break;
        case 'no_show': statusBadge = '<span class="badge badge-error">Неявка</span>'; break;
        case 'cancelled': statusBadge = '<span class="badge" style="background:rgba(255,255,255,0.1);color:var(--text-sec)">Отменён</span>'; break;
        default: statusBadge = `<span class="badge">${esc(b.status)}</span>`;
      }

      return `<tr>
        <td>${b.date}</td>
        <td>${b.start_time?.slice(0,5)} – ${b.end_time?.slice(0,5)}</td>
        <td>${esc(clubName)}</td>
        <td>${esc(userName)}</td>
        <td><span style="color:${zoneColor};font-weight:600">${zoneLabel}</span></td>
        <td>${b.duration_hours || '—'} ч</td>
        <td>${statusBadge}</td>
      </tr>`;
    }).join('');
  } catch (e) {
    $('all-bookings-tbody').innerHTML = `<tr><td colspan="7" class="empty-cell">Ошибка: ${esc(e.message)}</td></tr>`;
  }
}

/* ═══════════════════════════════════════════════
   13. FINANCIAL ANALYTICS + WEEKLY REPORT
   ═══════════════════════════════════════════════ */
async function loadFinance() {
  try {
    const startOfMonth = new Date(); startOfMonth.setDate(1); startOfMonth.setHours(0,0,0,0);
    const isoMonth = startOfMonth.toISOString();

    // All 3 finance stat queries in parallel
    const [rApproved, rActive, rChurned] = await Promise.all([
      sb.from('subscription_requests').select('amount_uzs').eq('status', 'approved').gte('created_at', isoMonth),
      sb.from('subscriptions').select('*', { count: 'exact', head: true }).eq('status', 'active'),
      sb.from('subscriptions').select('*', { count: 'exact', head: true }).in('status', ['expired', 'cancelled']).gte('updated_at', isoMonth),
    ]);

    const mrr = (rApproved.data || []).reduce((s, p) => s + (p.amount_uzs || 0), 0);
    const activeSubCount = rActive.count || 0;
    const arpu = activeSubCount ? Math.round(mrr / activeSubCount) : 0;
    const churnedCount = rChurned.count || 0;
    const totalSubsStart = activeSubCount + churnedCount;
    const churnRate = totalSubsStart ? ((churnedCount / totalSubsStart) * 100).toFixed(1) : '0';
    const churnDecimal = parseFloat(churnRate) / 100;
    const ltv = churnDecimal > 0 ? Math.round(arpu / churnDecimal) : arpu * 12;

    $('f-mrr').textContent = fmt(mrr) + ' UZS';
    $('f-arpu').textContent = fmt(arpu) + ' UZS';
    $('f-churn').textContent = churnRate + '%';
    $('f-ltv').textContent = fmt(ltv) + ' UZS';

    // Charts in parallel
    await Promise.all([loadMrrChart(), loadPlanDistChart(), loadChurnChart(), loadCohortChart()]);
  } catch (e) { console.error('Finance error:', e); }
}

async function loadMrrChart() {
  const months = [];
  for (let i = 5; i >= 0; i--) {
    const d = new Date(); d.setMonth(d.getMonth() - i);
    months.push({ start: new Date(d.getFullYear(), d.getMonth(), 1), end: new Date(d.getFullYear(), d.getMonth() + 1, 0) });
  }
  const labels = months.map(m => m.start.toLocaleString('ru-RU', { month: 'short' }));
  const results = await Promise.all(months.map(m =>
    sb.from('subscription_requests').select('amount_uzs').eq('status', 'approved')
      .gte('created_at', m.start.toISOString()).lte('created_at', m.end.toISOString())
  ));
  const values = results.map(r => (r.data || []).reduce((s, p) => s + (p.amount_uzs || 0), 0));
  renderChart('chart-mrr', 'bar', labels, values, 'MRR (UZS)', '#6366F1');
}

async function loadPlanDistChart() {
  const { data } = await sb.from('subscriptions').select('plan').eq('status', 'active');
  const dist = {};
  (data || []).forEach(s => { dist[s.plan] = (dist[s.plan] || 0) + 1; });
  const labels = Object.keys(dist);
  const values = Object.values(dist);
  const colors = ['#6366F1', '#10B981', '#F59E0B', '#EF4444', '#8B5CF6'];
  renderChart('chart-plan-dist', 'bar', labels.map(l => l.toUpperCase()), values, 'Подписок', colors.slice(0, labels.length));
}

async function loadChurnChart() {
  const months = [];
  for (let i = 5; i >= 0; i--) {
    const d = new Date(); d.setMonth(d.getMonth() - i);
    months.push({ start: new Date(d.getFullYear(), d.getMonth(), 1), end: new Date(d.getFullYear(), d.getMonth() + 1, 0) });
  }
  const labels = months.map(m => m.start.toLocaleString('ru-RU', { month: 'short' }));
  const results = await Promise.all(months.map(async m => {
    const [churnedRes, activeRes] = await Promise.all([
      sb.from('subscriptions').select('*', { count: 'exact', head: true })
        .in('status', ['expired', 'cancelled']).gte('updated_at', m.start.toISOString()).lte('updated_at', m.end.toISOString()),
      sb.from('subscriptions').select('*', { count: 'exact', head: true })
        .eq('status', 'active').lte('created_at', m.end.toISOString()),
    ]);
    const churned = churnedRes.count || 0;
    const active = activeRes.count || 0;
    const total = active + churned;
    return total > 0 ? parseFloat((churned / total * 100).toFixed(1)) : 0;
  }));
  renderChart('chart-churn', 'line', labels, results, 'Churn %', '#EF4444');
}

async function loadCohortChart() {
  const months = [];
  for (let i = 5; i >= 0; i--) {
    const d = new Date(); d.setMonth(d.getMonth() - i);
    months.push({ start: new Date(d.getFullYear(), d.getMonth(), 1), end: new Date(d.getFullYear(), d.getMonth() + 1, 0) });
  }
  const labels = months.map(m => m.start.toLocaleString('ru-RU', { month: 'short' }));
  const results = await Promise.all(months.map(async m => {
    const { data: cohortUsers } = await sb.from('users').select('id')
      .gte('created_at', m.start.toISOString()).lte('created_at', m.end.toISOString());
    const userIds = (cohortUsers || []).map(u => u.id);
    if (userIds.length === 0) return 0;
    const { count: retained } = await sb.from('subscriptions').select('*', { count: 'exact', head: true })
      .eq('status', 'active').in('user_id', userIds);
    return parseFloat(((retained || 0) / userIds.length * 100).toFixed(1));
  }));
  renderChart('chart-cohort', 'bar', labels, results, 'Удержание %', '#10B981');
}

/* ── WEEKLY REPORT ──────────────────────────── */
async function generateWeeklyReport() {
  showToast('Генерация отчёта...');
  try {
    const now = new Date();
    const weekAgo = new Date(); weekAgo.setDate(weekAgo.getDate() - 7);
    const isoWeekAgo = weekAgo.toISOString();

    const { count: newUsers } = await sb.from('users').select('*', { count: 'exact', head: true }).gte('created_at', isoWeekAgo);
    const { data: weekPayments } = await sb.from('subscription_requests').select('amount_uzs').eq('status', 'approved').gte('created_at', isoWeekAgo);
    const weekRevenue = (weekPayments || []).reduce((s, p) => s + (p.amount_uzs || 0), 0);
    const { count: weekVisits } = await sb.from('visits').select('*', { count: 'exact', head: true }).gte('created_at', isoWeekAgo);
    const { count: newSubs } = await sb.from('subscriptions').select('*', { count: 'exact', head: true }).gte('created_at', isoWeekAgo);
    const { count: totalUsers } = await sb.from('users').select('*', { count: 'exact', head: true });
    const { count: activeSubs } = await sb.from('subscriptions').select('*', { count: 'exact', head: true }).eq('status', 'active');
    const { count: totalClubs } = await sb.from('clubs').select('*', { count: 'exact', head: true }).eq('status', 'active');
    const { count: openTickets } = await sb.from('support_tickets').select('*', { count: 'exact', head: true }).eq('status', 'open');

    const reportCard = $('weekly-report-card');
    reportCard.style.display = 'block';
    $('weekly-report-body').innerHTML = `
      <div class="report-section">
        <h4>Период: ${fmtDate(weekAgo)} — ${fmtDate(now)}</h4>
        <div class="report-grid">
          <div class="report-item"><div class="report-item-label">Новых пользователей</div><div class="report-item-value">${fmt(newUsers)}</div></div>
          <div class="report-item"><div class="report-item-label">Выручка за неделю</div><div class="report-item-value">${fmt(weekRevenue)} UZS</div></div>
          <div class="report-item"><div class="report-item-label">Визитов</div><div class="report-item-value">${fmt(weekVisits)}</div></div>
          <div class="report-item"><div class="report-item-label">Новых подписок</div><div class="report-item-value">${fmt(newSubs)}</div></div>
        </div>
      </div>
      <div class="report-section">
        <h4>Общие показатели</h4>
        <div class="report-grid">
          <div class="report-item"><div class="report-item-label">Всего пользователей</div><div class="report-item-value">${fmt(totalUsers)}</div></div>
          <div class="report-item"><div class="report-item-label">Активных подписок</div><div class="report-item-value">${fmt(activeSubs)}</div></div>
          <div class="report-item"><div class="report-item-label">Активных клубов</div><div class="report-item-value">${fmt(totalClubs)}</div></div>
          <div class="report-item"><div class="report-item-label">Открытых тикетов</div><div class="report-item-value">${fmt(openTickets || 0)}</div></div>
        </div>
      </div>
      <div class="report-actions">
        <button class="btn-primary btn-inline" onclick="downloadWeeklyReport()">Скачать PDF-отчёт</button>
        <button class="btn-secondary" onclick="copyReportText()">Копировать текст</button>
      </div>`;

    window.__lastReport = { newUsers, weekRevenue, weekVisits, newSubs, totalUsers, activeSubs, totalClubs, openTickets, from: fmtDate(weekAgo), to: fmtDate(now) };
    logAction(t('log_report_generated'), 'report', null);
  } catch (e) { showToast(e.message, 'error'); }
}

function downloadWeeklyReport() {
  const r = window.__lastReport;
  if (!r) return;
  const text = `PlayPass — Еженедельный отчёт\n${r.from} — ${r.to}\n\nНовых пользователей: ${r.newUsers}\nВыручка: ${fmt(r.weekRevenue)} UZS\nВизитов: ${r.weekVisits}\nНовых подписок: ${r.newSubs}\n\nВсего пользователей: ${r.totalUsers}\nАктивных подписок: ${r.activeSubs}\nАктивных клубов: ${r.totalClubs}\nОткрытых тикетов: ${r.openTickets}`;
  const blob = new Blob([text], { type: 'text/plain;charset=utf-8' });
  const link = document.createElement('a');
  link.href = URL.createObjectURL(blob);
  link.download = `playpass_report_${r.from}_${r.to}.txt`;
  link.click();
}

function copyReportText() {
  const r = window.__lastReport;
  if (!r) return;
  const text = `PlayPass — Еженедельный отчёт (${r.from} — ${r.to})\nНовых пользователей: ${r.newUsers} | Выручка: ${fmt(r.weekRevenue)} UZS | Визитов: ${r.weekVisits} | Новых подписок: ${r.newSubs}\nВсего: ${r.totalUsers} юзеров, ${r.activeSubs} подписок, ${r.totalClubs} клубов, ${r.openTickets} тикетов`;
  navigator.clipboard.writeText(text).then(() => showToast('Скопировано')).catch(e => console.warn('Clipboard copy failed:', e));
}

function exportFinanceCSV() {
  const r = window.__lastReport;
  if (!r) { showToast('Сначала сгенерируйте отчёт', 'error'); return; }
  downloadCSV('finance_report.csv',
    ['Метрика', 'Значение'],
    [['MRR', $('f-mrr').textContent], ['ARPU', $('f-arpu').textContent], ['Churn Rate', $('f-churn').textContent], ['LTV', $('f-ltv').textContent],
     ['Новых за неделю', r.newUsers], ['Выручка за неделю', r.weekRevenue], ['Визитов за неделю', r.weekVisits]]);
}

/* ── SIDEBAR TOGGLE ──────────────────────────── */
function toggleSidebar() {
  const sidebar = $('sidebar');
  const main = document.querySelector('.main-content');
  const btn = $('sidebar-toggle');
  const collapsed = sidebar.classList.toggle('collapsed');
  main.classList.toggle('expanded', collapsed);
  btn.classList.toggle('visible', collapsed);
  btn.innerHTML = collapsed ? '&#9776;' : '&laquo;';
  if (yandexMap) setTimeout(() => yandexMap.container.fitToViewport(), 300);
}

/* ── MODAL ───────────────────────────────────── */
function openModal() { $('modal-overlay').classList.remove('hidden'); }
function closeModal() { $('modal-overlay').classList.add('hidden'); }

/* ── INIT ────────────────────────────────────── */
initTheme();
applyLanguage();
checkSession();
document.addEventListener('keydown', (e) => {
  if (e.key === 'Enter' && !$('login-page').classList.contains('hidden')) handleLogin();
  if (e.key === 'Escape') closeModal();
});
