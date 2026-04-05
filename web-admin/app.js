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
      const { data: u } = await sb.from('users').select('name').eq('id', v.user_id).single();
      v.user_name = u?.name;
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
  const csv = rows.map(r => r.map(c => `"${c}"`).join(';')).join('\n');
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
  try { await sb.functions.invoke('qr-validate', { body: { club_id: currentClub.id, regenerate: true } }); } catch (_) {}
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
  const { data, error } = await sb.from('club_pcs').select('*, users:current_user_id(name)').eq('club_id', currentClub.id).order('pc_number');
  if (error) { $('pc-grid').innerHTML = `<div class="empty-state">${t('error_prefix')}: ${escHtml(error.message)}</div>`; return; }
  const pcs = data || [];
  renderPcSummary(pcs);
  renderPcGrid(pcs);
}

function renderPcSummary(pcs) {
  const counts = { free: 0, busy: 0, broken: 0, reserved: 0 };
  pcs.forEach(p => counts[p.status] = (counts[p.status] || 0) + 1);
  $('pc-summary').innerHTML = Object.entries(counts).map(([s, c]) =>
    `<span><span class="count count-${s}">${c}</span> ${t('pcs_' + s)}</span>`
  ).join('');
}

function renderPcGrid(pcs) {
  const grid = $('pc-grid');
  if (!pcs.length) { grid.innerHTML = `<div class="empty-state">${t('pcs_empty')}</div>`; return; }
  grid.innerHTML = pcs.map(p => {
    const userName = p.status === 'busy' && p.users ? escHtml(p.users.name) : '';
    return `<div class="pc-card pc-${p.status}" onclick="showEditPcModal('${p.id}')">
      <div class="pc-number">${p.pc_number}</div>
      <div class="pc-label">${escHtml(p.label || p.zone)}</div>
      <span class="pc-status-dot"></span>
      ${userName ? `<div class="pc-user">${userName}</div>` : ''}
      ${p.status === 'busy' && p.session_start ? `<div class="pc-user">${elapsed(p.session_start)}</div>` : ''}
    </div>`;
  }).join('');
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
  });
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
      <button class="btn-primary btn-inline" onclick="savePc('${pc?.id || ''}')">${t('btn_save')}</button>
      ${pc ? `<button class="btn-delete" onclick="deletePc('${pc.id}')" style="margin-left:auto">${t('btn_delete')}</button>` : ''}
    </div>`;
}

async function savePc(id) {
  const payload = {
    pc_number: parseInt($('pc-number').value) || 1,
    label: $('pc-label').value.trim(),
    zone: $('pc-zone').value.trim() || 'main',
    status: $('pc-status').value,
    club_id: currentClub.id,
  };
  try {
    if (id) { await sb.from('club_pcs').update(payload).eq('id', id); }
    else { await sb.from('club_pcs').insert(payload); }
    showToast(t('pcs_saved')); closeModal(); loadPcs();
  } catch (e) { showToast(e.message, 'error'); }
}

async function deletePc(id) {
  if (!confirm(t('confirm_delete'))) return;
  await sb.from('club_pcs').delete().eq('id', id);
  showToast(t('pcs_deleted')); closeModal(); loadPcs();
}

/* ═══════════════════════════════════════════════
   6. ACTIVE SESSIONS
   ═══════════════════════════════════════════════ */
async function loadSessions() {
  if (!currentClub) return;
  if (sessionTimer) clearInterval(sessionTimer);
  const { data } = await sb.from('club_pcs').select('*, users:current_user_id(name, subscriptions(hours_balance))').eq('club_id', currentClub.id).eq('status', 'busy').order('session_start');
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
    const elapsedStr = elapsedMin < 60 ? `${elapsedMin} мин` : `${Math.floor(elapsedMin / 60)}ч ${elapsedMin % 60}м`;
    const sub = s.users?.subscriptions?.[0];
    const remaining = sub ? (sub.hours_balance === -1 ? t('sess_unlimited') : `${sub.hours_balance}ч`) : '—';
    return `<tr data-session-start="${s.session_start}">
      <td><strong>${s.pc_number}</strong> ${escHtml(s.label || '')}</td>
      <td>${escHtml(userName)}</td>
      <td>${start}</td>
      <td class="sess-elapsed">${elapsedStr}</td>
      <td>${remaining}</td>
      <td><button class="btn-small btn-reject" onclick="endSession('${s.id}')">${t('sess_end')}</button></td>
    </tr>`;
  }).join('');
}

function updateSessionTimers() {
  document.querySelectorAll('#sessions-tbody tr[data-session-start]').forEach(row => {
    const start = row.getAttribute('data-session-start');
    if (!start) return;
    const elapsedMin = Math.floor((Date.now() - new Date(start).getTime()) / 60000);
    const cell = row.querySelector('.sess-elapsed');
    if (cell) cell.textContent = elapsedMin < 60 ? `${elapsedMin} мин` : `${Math.floor(elapsedMin / 60)}ч ${elapsedMin % 60}м`;
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
  const { data } = await sb.from('bookings').select('*, club_pcs(pc_number, label), users(name)').eq('club_id', currentClub.id).eq('date', date).order('start_time');
  renderBookingsTable(data || []);
}

function renderBookingsTable(bookings) {
  const tbody = $('bookings-tbody');
  if (!bookings.length) { tbody.innerHTML = `<tr><td colspan="5" class="empty-cell">${t('book_empty')}</td></tr>`; return; }
  const statusMap = { pending: t('book_pending'), confirmed: t('book_confirmed'), cancelled: t('book_cancelled'), completed: t('book_completed') };
  tbody.innerHTML = bookings.map(b => {
    const pcLabel = b.club_pcs ? `#${b.club_pcs.pc_number} ${b.club_pcs.label || ''}` : '—';
    const actions = b.status === 'pending' ? `<button class="btn-small btn-approve" onclick="confirmBooking('${b.id}')">${t('book_confirm')}</button><button class="btn-small btn-reject" onclick="cancelBooking('${b.id}')">${t('book_cancel')}</button>` :
                    b.status === 'confirmed' ? `<button class="btn-small btn-reject" onclick="cancelBooking('${b.id}')">${t('book_cancel')}</button>` : '';
    return `<tr><td>${b.start_time?.slice(0,5)} – ${b.end_time?.slice(0,5)}</td><td>${escHtml(pcLabel)}</td><td>${escHtml(b.users?.name || '—')}</td><td>${statusMap[b.status] || b.status}</td><td>${actions}</td></tr>`;
  }).join('');
}

async function confirmBooking(id) {
  await sb.from('bookings').update({ status: 'confirmed' }).eq('id', id);
  showToast(t('book_confirmed_toast')); loadBookings();
}

async function cancelBooking(id) {
  await sb.from('bookings').update({ status: 'cancelled' }).eq('id', id);
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
    <td><button class="btn-edit" onclick="showEditStaffModal('${s.id}')">✏️</button> <button class="btn-small btn-secondary" onclick="toggleStaffActive('${s.id}', ${s.is_active})">${s.is_active ? '⏸' : '▶'}</button></td>
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
  });
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
      <button class="btn-primary btn-inline" onclick="saveStaff('${s?.id || ''}')">${t('btn_save')}</button>
    </div>`;
}

async function saveStaff(id) {
  const payload = {
    name: $('staff-name').value.trim(), role: $('staff-role').value,
    phone: $('staff-phone').value.trim(), shift_pattern: $('staff-shift').value,
    club_id: currentClub.id,
  };
  if (!payload.name) { showToast(t('staff_label_name'), 'error'); return; }
  try {
    if (id) { await sb.from('club_staff').update(payload).eq('id', id); }
    else { await sb.from('club_staff').insert(payload); }
    showToast(t('staff_saved')); closeModal(); loadStaff();
  } catch (e) { showToast(e.message, 'error'); }
}

async function toggleStaffActive(id, isActive) {
  await sb.from('club_staff').update({ is_active: !isActive }).eq('id', id);
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
  if (analyticsCharts['chart-hours']) analyticsCharts['chart-hours'].destroy();
  analyticsCharts['chart-hours'] = new Chart($('chart-hours'), {
    type: 'bar',
    data: { labels: Array.from({ length: 24 }, (_, i) => `${i}:00`), datasets: [{ data: byHour, backgroundColor: hourColors, borderRadius: 4 }] },
    options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false } },
      scales: { x: { grid: { color: gridColor }, ticks: { color: tickColor, font: { size: 10 } } }, y: { grid: { color: gridColor }, ticks: { color: tickColor, font: { size: 10 } }, beginAtZero: true } } },
  });

  // Weekday chart
  const dayLabels = ['analytics_mon','analytics_tue','analytics_wed','analytics_thu','analytics_fri','analytics_sat','analytics_sun'].map(k => t(k));
  if (analyticsCharts['chart-weekdays']) analyticsCharts['chart-weekdays'].destroy();
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
  const { data } = await sb.from('club_pcs').select('*').eq('club_id', currentClub.id).order('pc_number');
  if (!data?.length) { showToast('Нет данных для экспорта', 'error'); return; }
  const rows = [['№ ПК', 'Зона', 'Характеристики', 'Статус']];
  data.forEach(pc => rows.push([pc.pc_number, pc.zone || 'basic', pc.specs || '', pc.status || 'free']));
  _downloadCSV(`pcs_${currentClub.name}_${toDateInput(new Date())}.csv`, rows);
}

async function exportBookingsCSV() {
  if (!currentClub) return;
  const { data } = await sb.from('bookings').select('*, users(name)').eq('club_id', currentClub.id).order('booking_time', { ascending: false }).limit(500);
  if (!data?.length) { showToast('Нет данных для экспорта', 'error'); return; }
  const rows = [['Дата/время', 'Пользователь', 'Зона', 'Длительность', 'Статус']];
  data.forEach(b => rows.push([
    formatDateTime(new Date(b.booking_time)),
    b.users?.name || '',
    b.zone || 'basic',
    (b.duration_hours || 2) + ' ч',
    b.status || '',
  ]));
  _downloadCSV(`bookings_${currentClub.name}_${toDateInput(new Date())}.csv`, rows);
}

async function exportStaffCSV() {
  if (!currentClub) return;
  const { data } = await sb.from('club_staff').select('*').eq('club_id', currentClub.id).order('name');
  if (!data?.length) { showToast('Нет данных для экспорта', 'error'); return; }
  const rows = [['Имя', 'Должность', 'Телефон', 'Смена']];
  data.forEach(s => rows.push([s.name, s.role || '', s.phone || '', s.shift || '']));
  _downloadCSV(`staff_${currentClub.name}_${toDateInput(new Date())}.csv`, rows);
}

async function exportFinanceCSV() {
  if (!currentClub) return;
  const { data } = await sb.from('payouts').select('*').eq('club_id', currentClub.id).order('period_month', { ascending: false });
  if (!data?.length) { showToast('Нет данных для экспорта', 'error'); return; }
  const rows = [['Период', 'Визиты', 'Сумма', 'Статус', 'Дата выплаты']];
  data.forEach(p => rows.push([
    p.period_month,
    p.visit_count || 0,
    formatMoney(p.amount || 0),
    p.status || '',
    p.paid_at ? formatDateTime(new Date(p.paid_at)) : '',
  ]));
  _downloadCSV(`finance_${currentClub.name}_${toDateInput(new Date())}.csv`, rows);
}
