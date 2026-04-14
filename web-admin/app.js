/* ═══════════════════════════════════════════════
   PlayPass — Club Admin Panel v2
   Vanilla JS + Supabase JS SDK v2
   ═══════════════════════════════════════════════ */

const SUPABASE_URL  = 'https://rizyqzjszaknzjboooow.supabase.co';
const SUPABASE_ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJpenlxempzemFrbnpqYm9vb293Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM4NjgzMzMsImV4cCI6MjA4OTQ0NDMzM30.cfptzTL4AkpN1xjGbIC4-yEjXVe8LPjdTNOzrYsykcs';
const RATE_PER_VISIT = 8000;

const { createClient } = supabase;
const sb = createClient(SUPABASE_URL, SUPABASE_ANON);

/* ── State ───────────────────────────────────── */
let currentUser = null;
let currentClub = null;
let allVisits = [];
let currentPage = 1;
const PAGE_SIZE = 50;
let realtimeChannel = null;
let sessionTimer = null;
let pcTimerInterval = null;
let analyticsCharts = {};
let currentLang = localStorage.getItem('lang') || 'ru';
const $ = (id) => document.getElementById(id);

/* ── i18n ────────────────────────────────────── */
function t(key) { return (LANG[currentLang] && LANG[currentLang][key]) || (LANG.ru[key]) || key; }

function applyLanguage() {
  document.querySelectorAll('[data-i18n]').forEach(el => {
    const v = t(el.getAttribute('data-i18n'));
    if (v) el.textContent = v;
  });
  document.querySelectorAll('[data-i18n-ph]').forEach(el => {
    const v = t(el.getAttribute('data-i18n-ph'));
    if (v) el.placeholder = v;
  });
  const ll = $('lang-label');
  if (ll) ll.textContent = currentLang === 'ru' ? 'UZ' : 'RU';
}

function toggleLang() {
  currentLang = currentLang === 'ru' ? 'uz' : 'ru';
  localStorage.setItem('lang', currentLang);
  applyLanguage();
}

/* ── Theme ───────────────────────────────────── */
function initTheme() {
  const saved = localStorage.getItem('theme') || 'dark';
  document.documentElement.dataset.theme = saved;
  const icon = $('theme-icon');
  if (icon) icon.textContent = saved === 'dark' ? '☀' : '🌙';
}

function toggleTheme() {
  const cur = document.documentElement.dataset.theme || 'dark';
  const next = cur === 'dark' ? 'light' : 'dark';
  document.documentElement.dataset.theme = next;
  localStorage.setItem('theme', next);
  const icon = $('theme-icon');
  if (icon) icon.textContent = next === 'dark' ? '☀' : '🌙';
}

/* ── Nav groups ──────────────────────────────── */
function toggleNavGroup(header) { header.parentElement.classList.toggle('open'); }

/* ── Helpers ─────────────────────────────────── */
function formatMoney(n) { return n ? new Intl.NumberFormat('ru').format(n) : '0'; }
function parseMoneyText(s) { return parseInt(s.replace(/\D/g, '')) || 0; }
function formatDateTime(d) { return d.toLocaleString(currentLang === 'uz' ? 'uz-UZ' : 'ru', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' }); }
function formatTime(d) { return d.toLocaleTimeString(currentLang === 'uz' ? 'uz-UZ' : 'ru', { hour: '2-digit', minute: '2-digit' }); }
function toDateInput(d) { return d.toISOString().split('T')[0]; }
function escHtml(str) { return String(str).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'); }
function esc(s) { return String(s).replace(/['"<>&]/g, c => ({'\'':'&#39;','"':'&quot;','<':'&lt;','>':'&gt;','&':'&amp;'})[c]); }

function showToast(msg, type) {
  const el = $('toast');
  if (!el) return;
  el.textContent = msg;
  el.style.borderColor = type === 'error' ? 'var(--error)' : 'var(--success)';
  el.classList.remove('hidden');
  setTimeout(() => el.classList.add('hidden'), 3000);
}

function openModal() { $('modal-overlay').classList.remove('hidden'); }
function closeModal() { $('modal-overlay').classList.add('hidden'); }

function elapsed(start) {
  const ms = Date.now() - new Date(start).getTime();
  const m = Math.floor(ms / 60000);
  if (m < 60) return m + ` ${t('min_ago')}`;
  const h = Math.floor(m / 60);
  return h + ` ${t('hr_ago')}`;
}

/* ── Init ────────────────────────────────────── */
document.addEventListener('DOMContentLoaded', async () => {
  initTheme();
  applyLanguage();

  const { data: { session } } = await sb.auth.getSession();
  if (session) {
    await initApp(session.user);
  } else {
    showLoginPage();
  }

  sb.auth.onAuthStateChange(async (event, session) => {
    if (event === 'SIGNED_IN' && session) await initApp(session.user);
    else if (event === 'SIGNED_OUT') showLoginPage();
  });

  const now = new Date();
  const firstDay = new Date(now.getFullYear(), now.getMonth(), 1);
  if ($('filter-from')) $('filter-from').value = toDateInput(firstDay);
  if ($('filter-to')) $('filter-to').value = toDateInput(now);
  if ($('booking-date')) $('booking-date').value = toDateInput(now);

  document.addEventListener('keydown', e => {
    if (e.key === 'Enter' && !$('login-page').classList.contains('hidden')) handleLogin();
    if (e.key === 'Escape') closeModal();
  });
});

async function initApp(user) {
  currentUser = user;
  const { data: admin, error: aErr } = await sb.from('admin_users').select('*').eq('id', user.id).single();
  if (aErr || !admin) { alert(t('login_err_no_admin')); showLoginPage(); return; }
  if (!admin.club_id) { alert(t('login_err_no_club')); showLoginPage(); return; }
  const { data: club, error: cErr } = await sb.from('clubs').select('*').eq('id', admin.club_id).single();
  if (cErr || !club) { alert(t('login_err_no_club')); showLoginPage(); return; }

  currentClub = club;
  $('club-name-sidebar').textContent = currentClub.name;
  showAppPage();
  await Promise.all([loadDashboard(), subscribeRealtime()]);
}

/* ── Auth ────────────────────────────────────── */
async function handleLogin() {
  const email = $('login-email').value.trim();
  const password = $('login-password').value;
  const errEl = $('login-error');
  errEl.classList.add('hidden');
  if (!email || !password) { showError(errEl, t('login_err_empty')); return; }
  const btn = document.querySelector('#login-page .btn-primary');
  btn.disabled = true; btn.textContent = '...';
  const { error } = await sb.auth.signInWithPassword({ email, password });
  btn.disabled = false; btn.textContent = t('login_btn');
  if (error) showError(errEl, t('login_err_bad'));
}

async function handleLogout() {
  if (realtimeChannel) sb.removeChannel(realtimeChannel);
  if (sessionTimer) clearInterval(sessionTimer);
  await sb.auth.signOut();
}

function showError(el, msg) { el.textContent = msg; el.classList.remove('hidden'); }
function showAppPage() { $('login-page').classList.add('hidden'); $('app-page').classList.remove('hidden'); }
function showLoginPage() { $('login-page').classList.remove('hidden'); $('app-page').classList.add('hidden'); }

/* ── Tab Navigation ──────────────────────────── */
function showTab(tabName, linkEl) {
  document.querySelectorAll('.tab-content').forEach(el => el.classList.add('hidden'));
  document.querySelectorAll('.nav-item').forEach(el => el.classList.remove('active'));
  $(`tab-${tabName}`).classList.remove('hidden');
  if (linkEl) {
    linkEl.classList.add('active');
    const group = linkEl.closest('.nav-group');
    if (group && !group.classList.contains('open')) group.classList.add('open');
  }

  // Clear timers when switching away from their respective tabs
  if (tabName !== 'pcs' && pcTimerInterval) { clearInterval(pcTimerInterval); pcTimerInterval = null; }
  if (tabName !== 'sessions' && sessionTimer) { clearInterval(sessionTimer); sessionTimer = null; }

  const loaders = {
    visits: loadVisits, finance: loadFinance, qr: loadQr,
    pcs: loadPcs, sessions: loadSessions, bookings: loadBookings,
    staff: loadStaff, analytics: loadAnalytics,
  };
  if (loaders[tabName]) loaders[tabName]();
  return false;
}

/* ═══════════════════════════════════════════════
   1. DASHBOARD
   ═══════════════════════════════════════════════ */
async function loadDashboard() {
  if (!currentClub) return;
  const now = new Date();
  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate()).toISOString();
  const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toISOString();

  const [todayRes, monthRes, totalRes, payoutRes] = await Promise.all([
    sb.from('visits').select('id', { count: 'exact', head: true }).eq('club_id', currentClub.id).gte('created_at', todayStart),
    sb.from('visits').select('id', { count: 'exact', head: true }).eq('club_id', currentClub.id).gte('created_at', monthStart),
    sb.from('visits').select('id', { count: 'exact', head: true }).eq('club_id', currentClub.id),
    sb.from('payouts').select('amount_uzs, status').eq('club_id', currentClub.id).eq('status', 'pending').gte('period_month', new Date(now.getFullYear(), now.getMonth(), 1).toISOString().split('T')[0]).maybeSingle(),
  ]);

  $('stat-today').textContent = todayRes.count ?? 0;
  $('stat-month').textContent = monthRes.count ?? 0;
  $('stat-total').textContent = totalRes.count ?? 0;
  $('stat-payout').textContent = formatMoney(payoutRes.data?.amount_uzs ?? (monthRes.count ?? 0) * RATE_PER_VISIT);

  const { data: recent } = await sb.from('visits').select('*, users(name)').eq('club_id', currentClub.id).order('created_at', { ascending: false }).limit(10);
  renderLiveVisits(recent ?? []);
}

function renderLiveVisits(visits) {
  const c = $('live-visits');
  if (!visits.length) { c.innerHTML = `<div class="empty-state">${t('dash_no_visits')}</div>`; return; }
  c.innerHTML = visits.map(v => {
    const name = v.users?.name || t('visits_unknown');
    return `<div class="live-visit-row"><div class="visit-avatar">●</div><div><div class="visit-name">${escHtml(name)}</div><div class="visit-time">${formatTime(new Date(v.created_at))}</div></div><span class="visit-badge">+1 ч</span></div>`;
  }).join('');
}

function prependLiveVisit(visit) {
  const c = $('live-visits');
  const empty = c.querySelector('.empty-state');
  if (empty) empty.remove();
  const row = document.createElement('div');
  row.className = 'live-visit-row';
  row.innerHTML = `<div class="visit-avatar">●</div><div><div class="visit-name">${escHtml(visit.user_name || t('visits_unknown'))}</div><div class="visit-time">${t('dash_just_now')}</div></div><span class="visit-badge">+1 ч</span>`;
  c.prepend(row);
  $('stat-today').textContent = (parseInt($('stat-today').textContent) || 0) + 1;
  $('stat-month').textContent = (parseInt($('stat-month').textContent) || 0) + 1;
  $('stat-payout').textContent = formatMoney(parseMoneyText($('stat-payout').textContent) + RATE_PER_VISIT);
}

/* ── Realtime ────────────────────────────────── */
async function subscribeRealtime() {
  if (!currentClub) return;
  realtimeChannel = sb.channel(`club_admin_${currentClub.id}`)
    .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'visits', filter: `club_id=eq.${currentClub.id}` }, async (payload) => {
      const v = payload.new;
      try {
        const { data: u } = await sb.from('users').select('name').eq('id', v.user_id).single();
        v.user_name = u?.name || 'Unknown';
      } catch(e) {
        v.user_name = '—';
        console.error('Failed to fetch user:', e);
      }
      prependLiveVisit(v);
    }).subscribe();
}

/* ═══════════════════════════════════════════════
   2. VISITS TABLE
   ═══════════════════════════════════════════════ */
async function loadVisits() {
  if (!currentClub) return;
  const from = $('filter-from').value, to = $('filter-to').value;
  let q = sb.from('visits').select('created_at, users(name), subscriptions(plan)').eq('club_id', currentClub.id).order('created_at', { ascending: false });
  if (from) q = q.gte('created_at', from + 'T00:00:00Z');
  if (to) q = q.lte('created_at', to + 'T23:59:59Z');
  const { data } = await q;
  allVisits = data ?? [];
  currentPage = 1;
  renderVisitsTable();
}

function filterVisitsTable() { currentPage = 1; renderVisitsTable(); }

function renderVisitsTable() {
  const search = $('filter-search').value.toLowerCase();
  const filtered = search ? allVisits.filter(v => (v.users?.name || '').toLowerCase().includes(search)) : allVisits;
  const totalPages = Math.max(1, Math.ceil(filtered.length / PAGE_SIZE));
  const start = (currentPage - 1) * PAGE_SIZE;
  const page = filtered.slice(start, start + PAGE_SIZE);
  const tbody = $('visits-tbody');
  if (!page.length) {
    tbody.innerHTML = `<tr><td colspan="3" class="empty-cell">${t('visits_empty')}</td></tr>`;
  } else {
    tbody.innerHTML = page.map(v => {
      const name = v.users?.name || t('visits_unknown');
      const plan = v.subscriptions?.plan || t('visits_no_plan');
      return `<tr><td>${formatDateTime(new Date(v.created_at))}</td><td>${escHtml(name)}</td><td><span class="plan-badge plan-${v.subscriptions?.plan || 'start'}">${plan}</span></td></tr>`;
    }).join('');
  }
  $('page-info').textContent = `${currentPage} / ${totalPages}`;
  $('btn-prev').disabled = currentPage <= 1;
  $('btn-next').disabled = currentPage >= totalPages;
}

function changePage(dir) { currentPage += dir; renderVisitsTable(); }

function exportCSV() {
  if (!allVisits.length) { showToast(t('visits_empty'), 'error'); return; }
  const rows = [[t('visits_th_date'), t('visits_th_user'), t('visits_th_plan')]];
  allVisits.forEach(v => rows.push([formatDateTime(new Date(v.created_at)), v.users?.name || '', v.subscriptions?.plan || '']));
  const csv = rows.map(r => r.map(c => `"${String(c).replace(/"/g,'""')}"`).join(';')).join('\n');
  const blob = new Blob(['\uFEFF' + csv], { type: 'text/csv;charset=utf-8;' });
  const a = document.createElement('a'); a.href = URL.createObjectURL(blob);
  a.download = `visits_${currentClub.name}_${toDateInput(new Date())}.csv`; a.click();
}

/* ═══════════════════════════════════════════════
   3. FINANCE
   ═══════════════════════════════════════════════ */
async function loadFinance() {
  if (!currentClub) return;
  const monthStart = new Date(new Date().getFullYear(), new Date().getMonth(), 1).toISOString();
  const [monthRes, payoutsRes] = await Promise.all([
    sb.from('visits').select('id', { count: 'exact', head: true }).eq('club_id', currentClub.id).gte('created_at', monthStart),
    sb.from('payouts').select('*').eq('club_id', currentClub.id).order('period_month', { ascending: false }),
  ]);
  $('finance-month-est').textContent = formatMoney((monthRes.count ?? 0) * RATE_PER_VISIT);
  const tbody = $('payouts-tbody');
  const payouts = payoutsRes.data;
  if (!payouts?.length) { tbody.innerHTML = `<tr><td colspan="5" class="empty-cell">${t('fin_empty')}</td></tr>`; return; }
  tbody.innerHTML = payouts.map(p => {
    const statusMap = { pending: t('fin_pending'), paid: t('fin_paid') };
    const period = new Date(p.period_month).toLocaleDateString(currentLang === 'uz' ? 'uz-UZ' : 'ru', { month: 'long', year: 'numeric' });
    return `<tr><td>${period}</td><td>${p.visit_count}</td><td>${formatMoney(p.amount_uzs)} UZS</td><td>${statusMap[p.status] || p.status}</td><td>${p.paid_at ? formatDateTime(new Date(p.paid_at)) : '—'}</td></tr>`;
  }).join('');
}

/* ═══════════════════════════════════════════════
   4. QR CODE
   ═══════════════════════════════════════════════ */
async function loadQr() {
  if (!currentClub) return;
  const c = $('qr-container');
  c.innerHTML = `<div class="loading">${t('loading')}</div>`;
  try {
    // Try Edge Function first
    const { data, error } = await sb.functions.invoke('qr-validate', { body: { club_id: currentClub.id } });
    if (error) throw error;
    if (data?.error) throw new Error(data.error);
    if (!data?.qr_payload) throw new Error('no payload');
    c.innerHTML = '<canvas id="qr-canvas"></canvas>';
    await QRCode.toCanvas($('qr-canvas'), data.qr_payload, { width: 240, margin: 1, color: { dark: '#000', light: '#fff' } });
  } catch (e) {
    // Fallback: generate QR locally with checkin URL
    const payload = `https://playpass.uz/checkin/${currentClub.id}`;
    c.innerHTML = '<canvas id="qr-canvas"></canvas>';
    try {
      await QRCode.toCanvas($('qr-canvas'), payload, { width: 240, margin: 1, color: { dark: '#000', light: '#fff' } });
    } catch (qrErr) {
      c.innerHTML = `<div class="loading" style="color:var(--error)">${t('error_prefix')}: ${qrErr.message}</div>`;
    }
  }
}

async function regenerateQr() {
  if (!confirm(t('qr_regen_confirm'))) return;
  try { await sb.functions.invoke('qr-validate', { body: { club_id: currentClub.id, regenerate: true } }); } catch (e) { console.error('QR regeneration failed:', e); showToast(t('qr_error'), 'error'); }
  await loadQr();
}

function downloadQrPdf() {
  const canvas = $('qr-canvas');
  if (!canvas) return;
  const url = canvas.toDataURL();
  const w = window.open('', '_blank');
  w.document.write(`<!DOCTYPE html><html><head><meta charset="UTF-8"><title>PlayPass QR — ${escHtml(currentClub.name)}</title><style>body{font-family:Arial,sans-serif;text-align:center;padding:40px;background:#fff;color:#000}.logo{font-size:28px;font-weight:900;color:#6366F1;margin-bottom:8px}.sub{font-size:16px;color:#555;margin-bottom:32px}img{width:280px;height:280px}.cn{font-size:24px;font-weight:700;margin-top:24px}.inst{font-size:14px;color:#666;margin-top:8px;line-height:1.6}@media print{body{padding:20px}}</style></head><body><div class="logo">PlayPass</div><div class="sub">Отсканируй и играй</div><img src="${url}" /><div class="cn">${escHtml(currentClub.name)}</div><div class="inst">Откройте PlayPass → Сканируйте QR → Чекин за 3 секунды!</div><script>window.onload=()=>window.print();<\/script></body></html>`);
  w.document.close();
}

/* ═══════════════════════════════════════════════
   5. PC MANAGEMENT
   ═══════════════════════════════════════════════ */

async function loadPcs() {
  if (!currentClub) return;
  const { data, error } = await sb.from('club_pcs').select('*, users:current_user_id(name, subscriptions(hours_balance))').eq('club_id', currentClub.id).order('pc_number');
  if (error) { $('pc-grid').innerHTML = `<div class="empty-state">${t('error_prefix')}: ${escHtml(error.message)}</div>`; return; }
  const pcs = data || [];
  renderPcSummary(pcs);
  renderPcGrid(pcs);
  // Start live timers on PC cards (every second)
  if (pcTimerInterval) clearInterval(pcTimerInterval);
  pcTimerInterval = setInterval(updatePcCardTimers, 1000);
}

function renderPcSummary(pcs) {
  const counts = { free: 0, busy: 0, broken: 0, reserved: 0 };
  pcs.forEach(p => counts[p.status] = (counts[p.status] || 0) + 1);
  const total = pcs.length;
  $('pc-summary').innerHTML = `<span><strong>${total}</strong> ${t('pcs_total')}</span>` +
    Object.entries(counts).map(([s, c]) =>
      `<span><span class="count count-${s}">${c}</span> ${t('pcs_' + s)}</span>`
    ).join('');
}

function renderPcGrid(pcs) {
  const grid = $('pc-grid');
  if (!pcs.length) { grid.innerHTML = `<div class="empty-state">${t('pcs_empty')}</div>`; return; }

  // Group PCs by zone
  const zones = {};
  pcs.forEach(p => {
    const z = p.zone || 'main';
    if (!zones[z]) zones[z] = [];
    zones[z].push(p);
  });

  grid.innerHTML = Object.entries(zones).map(([zoneName, zonePcs]) => {
    const zCounts = { free: 0, busy: 0, broken: 0, reserved: 0 };
    zonePcs.forEach(p => zCounts[p.status] = (zCounts[p.status] || 0) + 1);
    const total = zonePcs.length;

    const cards = zonePcs.map(p => {
      const userName = p.status === 'busy' && p.users ? escHtml(p.users.name) : '';
      const sub = p.users?.subscriptions?.[0];
      const balanceHrs = sub ? (sub.hours_balance === -1 ? '∞' : sub.hours_balance + 'ч') : '';
      return `<div class="pc-card pc-${p.status}" onclick="showEditPcModal('${esc(p.id)}')">
        <div class="pc-number">${p.pc_number}</div>
        <div class="pc-label">${escHtml(p.label || '')}</div>
        <span class="pc-status-dot"></span>
        ${userName ? `<div class="pc-user">${userName}</div>` : ''}
        ${p.status === 'busy' && p.session_start ? `<div class="pc-timer" data-start="${p.session_start}">⏱ ${elapsedDetailed(p.session_start)}</div>` : ''}
        ${p.status === 'busy' && balanceHrs ? `<div class="pc-balance">${t('pcs_balance')}: ${balanceHrs}</div>` : ''}
        ${p.status === 'reserved' ? `<div class="pc-reserved-label">🔒 ${t('pcs_reserved')}</div>` : ''}
      </div>`;
    }).join('');

    return `<div class="zone-group">
      <div class="zone-header">
        <div class="zone-title">
          <span class="zone-icon">🖥</span>
          <strong>${escHtml(zoneName)}</strong>
          <span class="zone-count">${total} ${t('pcs_pcs')}</span>
        </div>
        <div class="zone-stats">
          <span class="zone-stat zone-free">${zCounts.free} ${t('pcs_free')}</span>
          <span class="zone-stat zone-busy">${zCounts.busy} ${t('pcs_busy')}</span>
          ${zCounts.reserved ? `<span class="zone-stat zone-reserved">${zCounts.reserved} ${t('pcs_reserved')}</span>` : ''}
          ${zCounts.broken ? `<span class="zone-stat zone-broken">${zCounts.broken} ${t('pcs_broken')}</span>` : ''}
        </div>
      </div>
      <div class="zone-progress">
        <div class="zone-bar zone-bar-busy" style="width:${total ? (zCounts.busy / total * 100) : 0}%"></div>
        <div class="zone-bar zone-bar-reserved" style="width:${total ? (zCounts.reserved / total * 100) : 0}%"></div>
        <div class="zone-bar zone-bar-broken" style="width:${total ? (zCounts.broken / total * 100) : 0}%"></div>
      </div>
      <div class="zone-grid">${cards}</div>
    </div>`;
  }).join('');
}

function elapsedDetailed(start) {
  const ms = Date.now() - new Date(start).getTime();
  const totalSec = Math.floor(ms / 1000);
  const h = Math.floor(totalSec / 3600);
  const m = Math.floor((totalSec % 3600) / 60);
  const s = totalSec % 60;
  if (h > 0) return `${h}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
  return `${m}:${String(s).padStart(2, '0')}`;
}

function updatePcCardTimers() {
  document.querySelectorAll('.pc-timer[data-start]').forEach(el => {
    el.textContent = '⏱ ' + elapsedDetailed(el.dataset.start);
  });
}

function showAddPcModal() {
  $('modal-title').textContent = t('pcs_modal_add');
  $('modal-body').innerHTML = pcFormHtml();
  openModal();
}

function showEditPcModal(id) {
  sb.from('club_pcs').select('*').eq('id', id).single().then(({ data: pc }) => {
    if (!pc) return;
    $('modal-title').textContent = t('pcs_modal_edit');
    $('modal-body').innerHTML = pcFormHtml(pc);
    openModal();
  }).catch(e => { console.error(e); showToast(t('load_error'), 'error'); });
}

function pcFormHtml(pc = null) {
  const statuses = ['free', 'busy', 'broken', 'reserved'];
  return `
    <div class="form-group"><label>${t('pcs_label_number')}</label><input type="number" id="pc-number" value="${pc?.pc_number || ''}" placeholder="1" min="1" /></div>
    <div class="form-group"><label>${t('pcs_label_name')}</label><input type="text" id="pc-label" value="${escHtml(pc?.label || '')}" placeholder="Gaming PC" /></div>
    <div class="form-group"><label>${t('pcs_label_zone')}</label><input type="text" id="pc-zone" value="${escHtml(pc?.zone || 'main')}" placeholder="main" /></div>
    <div class="form-group"><label>${t('pcs_label_status')}</label><select id="pc-status">${statuses.map(s => `<option value="${s}" ${pc?.status === s ? 'selected' : ''}>${t('pcs_status_' + s)}</option>`).join('')}</select></div>
    <div class="modal-actions">
      <button class="btn-secondary" onclick="closeModal()">${t('btn_cancel')}</button>
      <button class="btn-primary btn-inline" onclick="savePc('${esc(pc?.id || '')}')">${t('btn_save')}</button>
      ${pc ? `<button class="btn-delete" onclick="deletePc('${esc(pc.id)}')" style="margin-left:auto">${t('btn_delete')}</button>` : ''}
    </div>`;
}

function showAddZoneModal() {
  $('modal-title').textContent = t('pcs_zone_add');
  $('modal-body').innerHTML = `
    <div class="form-group"><label>${t('pcs_zone_name')}</label><input type="text" id="zone-name" placeholder="VIP, Standard, Console..." /></div>
    <div class="form-group"><label>${t('pcs_zone_count')}</label><input type="number" id="zone-count" value="10" min="1" max="100" /></div>
    <div class="form-group"><label>${t('pcs_zone_start')}</label><input type="number" id="zone-start-num" value="1" min="1" /></div>
    <div class="form-group"><label>${t('pcs_label_name')} (${t('pcs_zone_prefix')})</label><input type="text" id="zone-pc-label" placeholder="PC" /></div>
    <div class="modal-actions">
      <button class="btn-secondary" onclick="closeModal()">${t('btn_cancel')}</button>
      <button class="btn-primary btn-inline" onclick="saveZone()">${t('pcs_zone_create')}</button>
    </div>`;
  openModal();
}

async function saveZone() {
  const name = $('zone-name').value.trim();
  const count = parseInt($('zone-count').value) || 10;
  const startNum = parseInt($('zone-start-num').value) || 1;
  const label = $('zone-pc-label').value.trim() || 'PC';
  if (!name) { showToast(t('pcs_zone_name_required'), 'error'); return; }

  const pcs = [];
  for (let i = 0; i < count; i++) {
    pcs.push({
      club_id: currentClub.id,
      pc_number: startNum + i,
      label: `${label} ${startNum + i}`,
      zone: name,
      status: 'free',
    });
  }

  const { error } = await sb.from('club_pcs').insert(pcs);
  if (error) { showToast(t('error_prefix') + ': ' + error.message, 'error'); return; }
  showToast(`${t('pcs_zone_created')}: ${name} (${count} ${t('pcs_pcs')})`);
  closeModal(); loadPcs();
}

async function savePc(id) {
  const payload = {
    pc_number: parseInt($('pc-number').value) || 1,
    label: $('pc-label').value.trim(),
    zone: $('pc-zone').value.trim() || 'main',
    status: $('pc-status').value,
    club_id: currentClub.id,
  };
  const { error } = id
    ? await sb.from('club_pcs').update(payload).eq('id', id)
    : await sb.from('club_pcs').insert(payload);
  if (error) { showToast(t('error_prefix') + ': ' + error.message, 'error'); return; }
  showToast(t('pcs_saved')); closeModal(); loadPcs();
}

async function deletePc(id) {
  if (!confirm(t('confirm_delete'))) return;
  const { error } = await sb.from('club_pcs').delete().eq('id', id);
  if (error) { showToast(t('error_prefix') + ': ' + error.message, 'error'); return; }
  showToast(t('pcs_deleted')); closeModal(); loadPcs();
}

/* ═══════════════════════════════════════════════
   6. ACTIVE SESSIONS
   ═══════════════════════════════════════════════ */
async function loadSessions() {
  if (!currentClub) return;
  if (sessionTimer) clearInterval(sessionTimer);
  const { data, error } = await sb.from('club_pcs').select('*, users:current_user_id(name, subscriptions(hours_balance))').eq('club_id', currentClub.id).eq('status', 'busy').order('session_start');
  if (error) { console.error('Sessions load error:', error); renderSessionsTable([]); return; }
  renderSessionsTable(data || []);
  sessionTimer = setInterval(() => updateSessionTimers(), 60000);
}

function renderSessionsTable(sessions) {
  const tbody = $('sessions-tbody');
  if (!sessions.length) { tbody.innerHTML = `<tr><td colspan="6" class="empty-cell">${t('sess_empty')}</td></tr>`; return; }
  tbody.innerHTML = sessions.map(s => {
    const userName = s.users?.name || '—';
    const start = s.session_start ? formatTime(new Date(s.session_start)) : '—';
    const elapsedMin = s.session_start ? Math.floor((Date.now() - new Date(s.session_start).getTime()) / 60000) : 0;
    const elapsedStr = elapsedMin < 60 ? `${elapsedMin} ${t('min_ago')}` : `${Math.floor(elapsedMin / 60)}ч ${elapsedMin % 60}м`;
    const sub = s.users?.subscriptions?.[0];
    const remaining = sub ? (sub.hours_balance === -1 ? t('sess_unlimited') : `${sub.hours_balance}ч`) : '—';
    return `<tr data-session-start="${s.session_start}">
      <td><strong>${s.pc_number}</strong> ${escHtml(s.label || '')}</td>
      <td>${escHtml(userName)}</td>
      <td>${start}</td>
      <td class="sess-elapsed">${elapsedStr}</td>
      <td>${remaining}</td>
      <td><button class="btn-small btn-reject" onclick="endSession('${esc(s.id)}')">${t('sess_end')}</button></td>
    </tr>`;
  }).join('');
}

function updateSessionTimers() {
  document.querySelectorAll('#sessions-tbody tr[data-session-start]').forEach(row => {
    const start = row.getAttribute('data-session-start');
    if (!start) return;
    const elapsedMin = Math.floor((Date.now() - new Date(start).getTime()) / 60000);
    const cell = row.querySelector('.sess-elapsed');
    if (cell) cell.textContent = elapsedMin < 60 ? `${elapsedMin} ${t('min_ago')}` : `${Math.floor(elapsedMin / 60)}ч ${elapsedMin % 60}м`;
  });
}

async function endSession(pcId) {
  if (!confirm(t('sess_end_confirm'))) return;
  try {
    const { data: pc } = await sb.from('club_pcs').select('*').eq('id', pcId).single();
    if (pc && pc.current_user_id && pc.session_start) {
      await sb.from('visits').insert({ club_id: currentClub.id, user_id: pc.current_user_id, created_at: pc.session_start });
    }
    await sb.from('club_pcs').update({ status: 'free', current_user_id: null, session_start: null }).eq('id', pcId);
    showToast(t('sess_ended')); loadSessions();
  } catch (e) { showToast(e.message, 'error'); }
}

/* ═══════════════════════════════════════════════
   7. BOOKINGS
   ═══════════════════════════════════════════════ */
async function loadBookings() {
  if (!currentClub) return;
  const date = $('booking-date').value || toDateInput(new Date());
  const { data } = await sb.from('bookings').select('*, users(name)').eq('club_id', currentClub.id).eq('date', date).order('start_time');
  renderBookingsTable(data || []);
}

function renderBookingsTable(bookings) {
  const tbody = $('bookings-tbody');
  if (!bookings.length) { tbody.innerHTML = `<tr><td colspan="6" class="empty-cell">${t('book_empty')}</td></tr>`; return; }
  const now = new Date();
  tbody.innerHTML = bookings.map(b => {
    const zone = b.zone || 'basic';
    const zoneLabel = zone === 'vip' ? 'VIP' : zone === 'pro' ? 'Про' : 'Базовая';
    const zoneColor = zone === 'vip' ? '#FBBF24' : zone === 'pro' ? '#A855F7' : '#10B981';

    // Status with grace period
    let statusHtml = '';
    let actions = '';
    const graceExpires = b.grace_expires_at ? new Date(b.grace_expires_at) : null;

    if (b.status === 'confirmed' && graceExpires && now > new Date(b.booking_time) && now < graceExpires) {
      const minsLeft = Math.ceil((graceExpires - now) / 60000);
      statusHtml = `<span class="badge badge-warning">⏳ ${minsLeft} мин</span>`;
      actions = `<button class="btn-small btn-approve" onclick="activateBooking('${esc(b.id)}')">Пришёл</button><button class="btn-small btn-reject" onclick="cancelBookingAdmin('${esc(b.id)}')">Отмена</button>`;
    } else if (b.status === 'confirmed') {
      statusHtml = `<span class="badge badge-info">Подтверждён</span>`;
      actions = `<button class="btn-small btn-approve" onclick="activateBooking('${esc(b.id)}')">Пришёл</button><button class="btn-small btn-reject" onclick="cancelBookingAdmin('${esc(b.id)}')">Отмена</button>`;
    } else if (b.status === 'active') {
      statusHtml = `<span class="badge badge-success">Активен</span>`;
      actions = `<button class="btn-small btn-approve" onclick="completeBooking('${esc(b.id)}')">Завершить</button>`;
    } else if (b.status === 'no_show') {
      statusHtml = `<span class="badge badge-danger">Неявка</span>`;
    } else if (b.status === 'completed') {
      statusHtml = `<span class="badge badge-success">✓ Готово</span>`;
    } else if (b.status === 'cancelled') {
      statusHtml = `<span class="badge badge-muted">Отменён</span>`;
    } else if (b.status === 'pending') {
      statusHtml = `<span class="badge badge-warning">Ожидает</span>`;
      actions = `<button class="btn-small btn-approve" onclick="confirmBooking('${esc(b.id)}')">Принять</button><button class="btn-small btn-reject" onclick="cancelBookingAdmin('${esc(b.id)}')">Отмена</button>`;
    }

    return `<tr>
      <td>${b.start_time?.slice(0,5)} – ${b.end_time?.slice(0,5)}</td>
      <td><span style="color:${zoneColor};font-weight:600">${zoneLabel}</span></td>
      <td>${escHtml(b.users?.name || '—')}</td>
      <td>${b.duration_hours || '—'} ч</td>
      <td>${statusHtml}</td>
      <td>${actions}</td>
    </tr>`;
  }).join('');
}

async function confirmBooking(id) {
  const grace = new Date(Date.now() + 15 * 60000).toISOString();
  const { error } = await sb.from('bookings').update({ status: 'confirmed', grace_expires_at: grace }).eq('id', id);
  if (error) { showToast(t('error_prefix') + ': ' + error.message, 'error'); return; }
  showToast(t('book_confirmed_toast')); loadBookings();
}

async function activateBooking(id) {
  const { error } = await sb.from('bookings').update({ status: 'active' }).eq('id', id);
  if (error) { showToast(t('error_prefix') + ': ' + error.message, 'error'); return; }
  showToast(t('client_arrived')); loadBookings();
}

async function completeBooking(id) {
  const { error } = await sb.from('bookings').update({ status: 'completed' }).eq('id', id);
  if (error) { showToast(t('error_prefix') + ': ' + error.message, 'error'); return; }
  showToast(t('booking_completed')); loadBookings();
}

async function cancelBookingAdmin(id) {
  const { error } = await sb.from('bookings').update({ status: 'cancelled' }).eq('id', id);
  if (error) { showToast(t('error_prefix') + ': ' + error.message, 'error'); return; }
  showToast(t('book_cancelled_toast')); loadBookings();
}

/* ═══════════════════════════════════════════════
   8. STAFF MANAGEMENT
   ═══════════════════════════════════════════════ */
async function loadStaff() {
  if (!currentClub) return;
  const { data } = await sb.from('club_staff').select('*').eq('club_id', currentClub.id).order('name');
  renderStaffTable(data || []);
}

function renderStaffTable(staff) {
  const tbody = $('staff-tbody');
  if (!staff.length) { tbody.innerHTML = `<tr><td colspan="6" class="empty-cell">${t('staff_empty')}</td></tr>`; return; }
  const roleMap = { admin: t('staff_role_admin'), cashier: t('staff_role_cashier'), tech: t('staff_role_tech') };
  const shiftMap = { morning: t('staff_shift_morning'), evening: t('staff_shift_evening'), night: t('staff_shift_night'), flexible: t('staff_shift_flexible') };
  tbody.innerHTML = staff.map(s => `<tr>
    <td><strong>${escHtml(s.name)}</strong></td>
    <td>${roleMap[s.role] || s.role}</td>
    <td>${escHtml(s.phone || '—')}</td>
    <td>${shiftMap[s.shift_pattern] || s.shift_pattern}</td>
    <td style="color:${s.is_active ? 'var(--success)' : 'var(--text-muted)'}">${s.is_active ? t('staff_active') : t('staff_inactive')}</td>
    <td><button class="btn-edit" onclick="showEditStaffModal('${esc(s.id)}')">✏️</button> <button class="btn-small btn-secondary" onclick="toggleStaffActive('${esc(s.id)}', ${s.is_active})">${s.is_active ? '⏸' : '▶'}</button></td>
  </tr>`).join('');
}

function showAddStaffModal() {
  $('modal-title').textContent = t('staff_modal_add');
  $('modal-body').innerHTML = staffFormHtml();
  openModal();
}

function showEditStaffModal(id) {
  sb.from('club_staff').select('*').eq('id', id).single().then(({ data: s }) => {
    if (!s) return;
    $('modal-title').textContent = t('staff_modal_edit');
    $('modal-body').innerHTML = staffFormHtml(s);
    openModal();
  }).catch(e => { console.error(e); showToast(t('load_error'), 'error'); });
}

function staffFormHtml(s = null) {
  const roles = ['admin', 'cashier', 'tech'];
  const shifts = ['morning', 'evening', 'night', 'flexible'];
  return `
    <div class="form-group"><label>${t('staff_label_name')}</label><input type="text" id="staff-name" value="${escHtml(s?.name || '')}" /></div>
    <div class="form-group"><label>${t('staff_label_role')}</label><select id="staff-role">${roles.map(r => `<option value="${r}" ${s?.role === r ? 'selected' : ''}>${t('staff_role_' + r)}</option>`).join('')}</select></div>
    <div class="form-group"><label>${t('staff_label_phone')}</label><input type="text" id="staff-phone" value="${escHtml(s?.phone || '')}" placeholder="+998 90 000 00 00" /></div>
    <div class="form-group"><label>${t('staff_label_shift')}</label><select id="staff-shift">${shifts.map(sh => `<option value="${sh}" ${s?.shift_pattern === sh ? 'selected' : ''}>${t('staff_shift_' + sh)}</option>`).join('')}</select></div>
    <div class="modal-actions">
      <button class="btn-secondary" onclick="closeModal()">${t('btn_cancel')}</button>
      <button class="btn-primary btn-inline" onclick="saveStaff('${esc(s?.id || '')}')">${t('btn_save')}</button>
    </div>`;
}

async function saveStaff(id) {
  const payload = {
    name: $('staff-name').value.trim(), role: $('staff-role').value,
    phone: $('staff-phone').value.trim(), shift_pattern: $('staff-shift').value,
    club_id: currentClub.id,
  };
  if (!payload.name) { showToast(t('staff_label_name'), 'error'); return; }
  const { error } = id
    ? await sb.from('club_staff').update(payload).eq('id', id)
    : await sb.from('club_staff').insert(payload);
  if (error) { showToast(t('error_prefix') + ': ' + error.message, 'error'); return; }
  showToast(t('staff_saved')); closeModal(); loadStaff();
}

async function toggleStaffActive(id, isActive) {
  const { error } = await sb.from('club_staff').update({ is_active: !isActive }).eq('id', id);
  if (error) { showToast(t('error_prefix') + ': ' + error.message, 'error'); return; }
  showToast(t('staff_toggled')); loadStaff();
}

/* ═══════════════════════════════════════════════
   9. ANALYTICS BY HOUR
   ═══════════════════════════════════════════════ */
async function loadAnalytics() {
  if (!currentClub) return;
  const thirtyAgo = new Date(); thirtyAgo.setDate(thirtyAgo.getDate() - 30);
  const { data: visits } = await sb.from('visits').select('created_at').eq('club_id', currentClub.id).gte('created_at', thirtyAgo.toISOString());
  if (!visits) return;

  // Aggregate by hour
  const byHour = new Array(24).fill(0);
  const byDay = new Array(7).fill(0);
  visits.forEach(v => {
    const d = new Date(v.created_at);
    byHour[d.getHours()]++;
    byDay[d.getDay() === 0 ? 6 : d.getDay() - 1]++; // Mon=0, Sun=6
  });

  // Peak hours
  const sorted = byHour.map((c, i) => ({ h: i, c })).sort((a, b) => b.c - a.c);
  const peaks = sorted.slice(0, 3).map(p => `${p.h}:00`);
  $('peak-hours').textContent = peaks.join(', ');
  $('peak-hours-sub').textContent = `${sorted[0]?.c || 0} ${t('analytics_avg')}`;

  // Charts
  const isLight = document.documentElement.dataset.theme === 'light';
  const gridColor = isLight ? 'rgba(0,0,0,0.06)' : 'rgba(255,255,255,0.06)';
  const tickColor = isLight ? '#9CA3AF' : '#6B7280';

  // Hourly chart
  const peakSet = new Set(sorted.slice(0, 3).map(p => p.h));
  const hourColors = byHour.map((_, i) => peakSet.has(i) ? '#6366F1BB' : '#6366F166');
  if (analyticsCharts['chart-hours']) try { analyticsCharts['chart-hours'].destroy(); } catch(_) {}
  analyticsCharts['chart-hours'] = new Chart($('chart-hours'), {
    type: 'bar',
    data: { labels: Array.from({ length: 24 }, (_, i) => `${i}:00`), datasets: [{ data: byHour, backgroundColor: hourColors, borderRadius: 4 }] },
    options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false } },
      scales: { x: { grid: { color: gridColor }, ticks: { color: tickColor, font: { size: 10 } } }, y: { grid: { color: gridColor }, ticks: { color: tickColor, font: { size: 10 } }, beginAtZero: true } } },
  });

  // Weekday chart
  const dayLabels = ['analytics_mon','analytics_tue','analytics_wed','analytics_thu','analytics_fri','analytics_sat','analytics_sun'].map(k => t(k));
  if (analyticsCharts['chart-weekdays']) try { analyticsCharts['chart-weekdays'].destroy(); } catch(_) {}
  analyticsCharts['chart-weekdays'] = new Chart($('chart-weekdays'), {
    type: 'bar',
    data: { labels: dayLabels, datasets: [{ data: byDay, backgroundColor: '#10B981BB', borderRadius: 4 }] },
    options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false } },
      scales: { x: { grid: { color: gridColor }, ticks: { color: tickColor, font: { size: 10 } } }, y: { grid: { color: gridColor }, ticks: { color: tickColor, font: { size: 10 } }, beginAtZero: true } } },
  });
}

/* ═══════════════════════════════════════════════
   EXPORT: PC, Bookings, Staff, Analytics
   ═══════════════════════════════════════════════ */
function _downloadCSV(filename, rows) {
  const csv = rows.map(r => r.map(c => `"${String(c).replace(/"/g,'""')}"`).join(';')).join('\n');
  const blob = new Blob(['\uFEFF' + csv], { type: 'text/csv;charset=utf-8;' });
  const a = document.createElement('a'); a.href = URL.createObjectURL(blob);
  a.download = filename; a.click();
}

async function exportPCsCSV() {
  if (!currentClub) return;
  const { data, error } = await sb.from('club_pcs').select('*').eq('club_id', currentClub.id).order('pc_number');
  if (error) { showToast(t('error_prefix') + ': ' + error.message, 'error'); return; }
  if (!data?.length) { showToast(t('no_data') || 'Нет данных для экспорта', 'error'); return; }
  const rows = [[t('pcs_label_number'), t('pcs_label_zone'), t('pcs_label_name'), t('pcs_label_status')]];
  data.forEach(pc => rows.push([pc.pc_number, pc.zone || 'main', pc.label || '', t('pcs_status_' + (pc.status || 'free'))]));
  _downloadCSV(`pcs_${currentClub.name}_${toDateInput(new Date())}.csv`, rows);
}

async function exportBookingsCSV() {
  if (!currentClub) return;
  const { data, error } = await sb.from('bookings').select('*, users(name), club_pcs(pc_number)').eq('club_id', currentClub.id).order('date', { ascending: false }).limit(500);
  if (error) { showToast(t('error_prefix') + ': ' + error.message, 'error'); return; }
  if (!data?.length) { showToast(t('book_empty'), 'error'); return; }
  const rows = [[t('book_th_time'), t('book_th_pc'), t('book_th_user'), t('book_th_status')]];
  data.forEach(b => rows.push([
    `${b.date} ${b.start_time || ''}-${b.end_time || ''}`,
    b.club_pcs?.pc_number || '—',
    b.users?.name || '',
    t('book_' + (b.status || 'pending')),
  ]));
  _downloadCSV(`bookings_${currentClub.name}_${toDateInput(new Date())}.csv`, rows);
}

async function exportStaffCSV() {
  if (!currentClub) return;
  const { data, error } = await sb.from('club_staff').select('*').eq('club_id', currentClub.id).order('name');
  if (error) { showToast(t('error_prefix') + ': ' + error.message, 'error'); return; }
  if (!data?.length) { showToast(t('staff_empty'), 'error'); return; }
  const rows = [[t('staff_th_name'), t('staff_th_role'), t('staff_th_phone'), t('staff_th_shift')]];
  data.forEach(s => rows.push([s.name, t('staff_role_' + (s.role || 'admin')), s.phone || '', t('staff_shift_' + (s.shift_pattern || 'flexible'))]));
  _downloadCSV(`staff_${currentClub.name}_${toDateInput(new Date())}.csv`, rows);
}

async function exportFinanceCSV() {
  if (!currentClub) return;
  const { data, error } = await sb.from('payouts').select('*').eq('club_id', currentClub.id).order('period_month', { ascending: false });
  if (error) { showToast(t('error_prefix') + ': ' + error.message, 'error'); return; }
  if (!data?.length) { showToast(t('fin_empty'), 'error'); return; }
  const rows = [[t('fin_th_period'), t('fin_th_visits'), t('fin_th_amount'), t('fin_th_status'), t('fin_th_date')]];
  data.forEach(p => rows.push([
    p.period_month,
    p.visit_count || 0,
    formatMoney(p.amount_uzs || 0),
    p.status === 'paid' ? t('fin_paid') : t('fin_pending'),
    p.paid_at ? formatDateTime(new Date(p.paid_at)) : '',
  ]));
  _downloadCSV(`finance_${currentClub.name}_${toDateInput(new Date())}.csv`, rows);
}

/* ═══════════════════════════════════════════════
   11. OCCUPANCY ANALYTICS (real-time snapshot recording)
   ═══════════════════════════════════════════════ */
async function recordOccupancySnapshot() {
  if (!currentClub) return;
  const { data } = await sb.from('club_pcs').select('status').eq('club_id', currentClub.id);
  if (!data) return;
  const total = data.length;
  const busy = data.filter(p => p.status === 'busy').length;
  const now = new Date();
  await sb.from('occupancy_snapshots').insert({
    club_id: currentClub.id,
    total_pcs: total,
    busy_pcs: busy,
    hour: now.getHours(),
    day_of_week: now.getDay() === 0 ? 6 : now.getDay() - 1,
  });
}

async function loadOccupancyAnalytics() {
  if (!currentClub) return;
  // Record current snapshot
  await recordOccupancySnapshot();

  const thirtyAgo = new Date();
  thirtyAgo.setDate(thirtyAgo.getDate() - 30);
  const { data } = await sb.from('occupancy_snapshots')
    .select('*')
    .eq('club_id', currentClub.id)
    .gte('recorded_at', thirtyAgo.toISOString())
    .order('recorded_at');

  if (!data || !data.length) {
    const el = $('occupancy-chart-wrap');
    if (el) el.innerHTML = `<p style="color:var(--text-muted);text-align:center;padding:40px">${t('analytics_no_data') || 'Нет данных за последние 30 дней'}</p>`;
    return;
  }

  // Aggregate average occupancy by hour
  const hourData = new Array(24).fill(null).map(() => ({ total: 0, busy: 0, count: 0 }));
  data.forEach(s => {
    hourData[s.hour].total += s.total_pcs;
    hourData[s.hour].busy += s.busy_pcs;
    hourData[s.hour].count++;
  });

  const avgOccupancy = hourData.map(h => h.count > 0 ? Math.round((h.busy / h.total) * 100) : 0);

  // Find peak hours
  const peakHours = avgOccupancy.map((v, i) => ({ h: i, v }))
    .sort((a, b) => b.v - a.v)
    .slice(0, 3)
    .map(p => `${p.h}:00 (${p.v}%)`);

  const peakEl = $('occupancy-peaks');
  if (peakEl) peakEl.innerHTML = `<strong>${t('analytics_peak_hours') || 'Пиковые часы'}:</strong> ${peakHours.join(', ')}`;

  // Render chart
  const isLight = document.documentElement.dataset.theme === 'light';
  const gridColor = isLight ? 'rgba(0,0,0,0.06)' : 'rgba(255,255,255,0.06)';
  const tickColor = isLight ? '#9CA3AF' : '#6B7280';

  const colors = avgOccupancy.map(v => v > 80 ? '#EF4444BB' : v > 50 ? '#F59E0BBB' : '#10B981BB');

  if (analyticsCharts['chart-occupancy']) try { analyticsCharts['chart-occupancy'].destroy(); } catch(_) {}
  analyticsCharts['chart-occupancy'] = new Chart($('chart-occupancy'), {
    type: 'bar',
    data: {
      labels: Array.from({ length: 24 }, (_, i) => `${i}:00`),
      datasets: [{
        label: t('analytics_occupancy') || 'Загруженность %',
        data: avgOccupancy,
        backgroundColor: colors,
        borderRadius: 4,
      }],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: { legend: { display: false } },
      scales: {
        x: { grid: { color: gridColor }, ticks: { color: tickColor, font: { size: 10 } } },
        y: { grid: { color: gridColor }, ticks: { color: tickColor, font: { size: 10 }, callback: v => v + '%' }, beginAtZero: true, max: 100 },
      },
    },
  });

  // Day of week aggregation
  const dayData = new Array(7).fill(null).map(() => ({ total: 0, busy: 0, count: 0 }));
  data.forEach(s => {
    dayData[s.day_of_week].total += s.total_pcs;
    dayData[s.day_of_week].busy += s.busy_pcs;
    dayData[s.day_of_week].count++;
  });
  const avgByDay = dayData.map(d => d.count > 0 ? Math.round((d.busy / d.total) * 100) : 0);
  const dayLabels = ['analytics_mon','analytics_tue','analytics_wed','analytics_thu','analytics_fri','analytics_sat','analytics_sun'].map(k => t(k));
  const dayColors = avgByDay.map(v => v > 80 ? '#EF4444BB' : v > 50 ? '#F59E0BBB' : '#10B981BB');

  if (analyticsCharts['chart-occupancy-days']) try { analyticsCharts['chart-occupancy-days'].destroy(); } catch(_) {}
  analyticsCharts['chart-occupancy-days'] = new Chart($('chart-occupancy-days'), {
    type: 'bar',
    data: {
      labels: dayLabels,
      datasets: [{ label: t('analytics_occupancy') || 'Загруженность %', data: avgByDay, backgroundColor: dayColors, borderRadius: 4 }],
    },
    options: {
      responsive: true, maintainAspectRatio: false,
      plugins: { legend: { display: false } },
      scales: {
        x: { grid: { color: gridColor }, ticks: { color: tickColor, font: { size: 10 } } },
        y: { grid: { color: gridColor }, ticks: { color: tickColor, font: { size: 10 }, callback: v => v + '%' }, beginAtZero: true, max: 100 },
      },
    },
  });
}
