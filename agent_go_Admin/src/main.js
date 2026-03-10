import { createClient } from '@supabase/supabase-js';
import Chart from 'chart.js/auto';

const SUPABASE_URL = 'https://covwkeaxwcrpyfxverkz.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNvdndrZWF4d2NycHlmeHZlcmt6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTA2MzczMjEsImV4cCI6MjA2NjIxMzMyMX0.eiXaZfiw4Tf0c9NkwhdbWms2va57Ohx6OjRfObtH4u4';
const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

const app = document.getElementById('app');

// State
let session = null;
let loading = true;
let users = [];

async function init() {
  const { data: { session: currentSession } } = await supabase.auth.getSession();
  session = currentSession;

  if (session && session.user.user_metadata?.role !== 'admin') {
    await supabase.auth.signOut();
    session = null;
    alert("Access Denied: Only administrators can access this portal.");
  }

  supabase.auth.onAuthStateChange(async (_event, newSession) => {
    if (newSession && newSession.user.user_metadata?.role !== 'admin') {
      await supabase.auth.signOut();
      session = null;
      alert("Access Denied: Only administrators can access this portal.");
    } else {
      session = newSession;
    }
    render();
  });

  render();
}

function render() {
  if (!session) {
    app.innerHTML = `
      <div class="auth-container">
        <div class="auth-card">
          <div class="logo">
            <svg viewBox="0 0 24 24" fill="none" class="shield-icon" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
            </svg>
            <h2>AgentGo Admin</h2>
          </div>
          <form id="login-form">
            <div class="input-group">
              <label>Email</label>
              <input type="email" id="email" placeholder="admin@agentgo.com" required />
            </div>
            <div class="input-group">
              <label>Password</label>
              <input type="password" id="password" required />
            </div>
            <button type="submit" class="primary-btn">Sign In</button>
            <p id="login-error" class="error-msg"></p>
          </form>
        </div>
      </div>
    `;

    document.getElementById('login-form').addEventListener('submit', async (e) => {
      e.preventDefault();
      const email = document.getElementById('email').value;
      const password = document.getElementById('password').value;
      const btn = e.target.querySelector('button');
      btn.innerText = 'Signing in...';

      const { data, error } = await supabase.auth.signInWithPassword({ email, password });
      if (error) {
        document.getElementById('login-error').innerText = error.message;
        btn.innerText = 'Sign In';
      } else if (data.user?.user_metadata?.role !== 'admin') {
        await supabase.auth.signOut();
        document.getElementById('login-error').innerText = 'Access Denied: Admin role required.';
        btn.innerText = 'Sign In';
      }
    });

  } else {
    app.innerHTML = `
      <div class="dashboard">
        <aside class="sidebar">
          <div class="logo">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
            </svg>
            <h2>AgentGo</h2>
          </div>
          <nav>
            <a href="#" class="tab-link active" data-tab="agents">Agents</a>
            <a href="#" class="tab-link" data-tab="revenue">Revenue</a>
          </nav>
        </aside>
        
        <main class="content">
          <header style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 30px;">
            <h1 id="page-title" style="margin-bottom: 0;">Manage Active Agents</h1>
            <div style="display: flex; gap: 12px; align-items: center;">
              <button id="theme-toggle" class="icon-btn" title="Toggle Theme" style="display: flex; align-items: center; justify-content: center; width: 44px; height: 44px; border-radius: 12px; background: var(--input-bg); color: var(--text-main); border: 1px solid var(--border-color); cursor: pointer; transition: all 0.3s ease;">
                <svg id="theme-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
                  <path id="theme-path" stroke-linecap="round" stroke-linejoin="round" d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364-6.364l-.707.707M6.343 17.657l-.707.707m12.728 0l-.707-.707M6.343 6.343l-.707-.707M12 8a4 4 0 100 8 4 4 0 000-8z" />
                </svg>
              </button>
              <button id="logout-btn" class="secondary-btn" style="height: 44px; padding: 0 15px; border-radius: 12px; display: flex; align-items: center; gap: 8px;">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><path d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" /></svg>
                Sign Out
              </button>
            </div>
          </header>
          
          <div class="actions" id="actions-bar">
            <button id="show-add-modal" class="primary-btn">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><path stroke-linecap="round" stroke-linejoin="round" d="M12 4v16m8-8H4" /></svg>
              Add New Agent
            </button>
          </div>

          <div class="card" id="agents-view">
            <table class="data-table">
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Agent Code</th>
                  <th>Email</th>
                  <th>Created At</th>
                  <th>Status</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody id="users-table-body">
                <tr><td colspan="6" class="loading">Loading agents...</td></tr>
              </tbody>
            </table>
          </div>

          <div class="card hidden" id="clients-view">
            <table class="data-table">
              <thead>
                <tr>
                  <th>Client Name</th>
                  <th>Agent Name</th>
                  <th>Policy Number</th>
                  <th>Sum</th>
                  <th>Created At</th>
                </tr>
              </thead>
              <tbody id="clients-table-body">
                <tr><td colspan="5" class="loading">Loading clients...</td></tr>
              </tbody>
            </table>
          </div>

          <div class="card hidden" id="revenue-view">
            <div style="padding: 30px;">
              <div class="stats-grid" style="margin-bottom: 30px;">
                <div class="stat-card">
                  <h3>Active Subscriptions</h3>
                  <p id="total-active-subs" class="stat-value">0</p>
                </div>
                <div class="stat-card">
                  <h3>Monthly Revenue</h3>
                  <p id="total-revenue" class="stat-value">₹0</p>
                </div>
              </div>

              <!-- Wave Chart Analysis -->
              <div class="card" style="margin-bottom: 40px; padding: 20px; background: rgba(0,0,0,0.2);">
                <h3 style="margin-bottom: 20px;">Revenue Wave Analysis</h3>
                <div style="height: 300px; width: 100%;">
                  <canvas id="revenue-chart"></canvas>
                </div>
              </div>

              <div style="display: grid; grid-template-columns: 1fr; gap: 30px;">
                <!-- Table 1: Revenue Management -->
                <div>
                  <h3 style="margin-bottom: 20px;">Subscription Management</h3>
                  <table class="data-table">
                    <thead>
                      <tr>
                        <th>Agent Name</th>
                        <th>Plan</th>
                        <th>Amount</th>
                        <th>Status</th>
                        <th>Joined At</th>
                      </tr>
                    </thead>
                    <tbody id="revenue-table-body">
                      <tr><td colspan="5" class="loading">Loading revenue data...</td></tr>
                    </tbody>
                  </table>
                </div>

                <!-- Table 2: Agent Payment Settings -->
                <div>
                  <h3 style="margin-bottom: 20px;">Agent Payment Status</h3>
                  <table class="data-table">
                    <thead>
                      <tr>
                        <th>Agent</th>
                        <th>Stripe ID</th>
                        <th>Last Payment</th>
                        <th>Auto-Renew</th>
                        <th>Quick Action</th>
                      </tr>
                    </thead>
                    <tbody id="payout-table-body">
                      <tr><td colspan="5" class="loading">No payment records found</td></tr>
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          </div>
        </main>
      </div>

      <!-- Add User Modal -->
      <div id="add-modal" class="modal-overlay hidden">
        <div class="modal">
          <div class="modal-header">
            <h3>Create New Agent</h3>
            <button id="close-modal" class="icon-btn">&times;</button>
          </div>
          <form id="add-user-form">
            <div class="input-group">
              <label>Full Name</label>
              <input type="text" id="new-name" placeholder="John Doe" required />
            </div>
            <div class="input-group">
              <label>Email</label>
              <input type="email" id="new-email" placeholder="john@example.com" required />
            </div>
            <div class="input-group">
              <label>Agent Code (8-digits)</label>
              <input type="text" id="new-agent-code" placeholder="12345678" pattern="[0-9]{8}" title="Must be 8 digits" required />
            </div>
            <div class="form-actions">
              <button type="button" class="secondary-btn" id="cancel-modal">Cancel</button>
              <button type="submit" class="primary-btn">Create Agent</button>
            </div>
            <p class="help-text">Credentials will be generated and displayed for you to send to the Agent.</p>
            <div id="credentials-box" class="hidden" style="margin-top: 15px; padding: 15px; background: rgba(0,0,0,0.3); border-radius: 8px; border: 1px dashed var(--primary);">
                <p style="font-size: 13px; margin-bottom: 5px; color: var(--text-muted);">Share these credentials with the agent:</p>
                <p style="font-size: 14px;"><strong>Email:</strong> <span id="cred-email"></span></p>
                <p style="font-size: 14px;"><strong>Password:</strong> <span id="cred-password"></span></p>
                <p style="font-size: 12px; margin-top: 8px; color: var(--primaryLight);"><a href="" id="mailto-link" style="color: var(--primary);">Open Email Client</a></p>
            </div>
            <p id="add-error" class="error-msg"></p>
            <p id="add-success" class="success-msg"></p>
          </form>
        </div>
      </div>
    `;

    document.getElementById('logout-btn').addEventListener('click', async () => {
      await supabase.auth.signOut();
    });

    // Modal logic
    const modal = document.getElementById('add-modal');
    document.getElementById('show-add-modal').addEventListener('click', () => {
      document.getElementById('add-user-form').reset();
      document.getElementById('credentials-box').classList.add('hidden');
      document.getElementById('add-error').innerText = '';
      document.getElementById('add-success').innerText = '';
      modal.classList.remove('hidden');
    });
    const closeModal = () => modal.classList.add('hidden');
    document.getElementById('close-modal').addEventListener('click', closeModal);
    document.getElementById('cancel-modal').addEventListener('click', closeModal);

    // Theme toggle logic
    const themeToggle = document.getElementById('theme-toggle');
    const themePath = document.getElementById('theme-path');

    const setDarkMode = (isDark) => {
      if (isDark) {
        document.body.classList.add('dark-mode');
        themePath.setAttribute('d', 'M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z');
      } else {
        document.body.classList.remove('dark-mode');
        themePath.setAttribute('d', 'M12 3v1m0 16v1m9-9h-1M4 12H3m15.364-6.364l-.707.707M6.343 17.657l-.707.707m12.728 0l-.707-.707M6.343 6.343l-.707-.707M12 8a4 4 0 100 8 4 4 0 000-8z');
      }
    };

    if (localStorage.getItem('agentgo-theme') === 'dark') {
      setDarkMode(true);
    }

    themeToggle.addEventListener('click', (e) => {
      e.preventDefault();
      const isDark = !document.body.classList.contains('dark-mode');
      setDarkMode(isDark);
      localStorage.setItem('agentgo-theme', isDark ? 'dark' : 'light');
    });

    // Form logic
    document.getElementById('add-user-form').addEventListener('submit', async (e) => {
      e.preventDefault();
      const name = document.getElementById('new-name').value;
      const email = document.getElementById('new-email').value;
      const agentCode = document.getElementById('new-agent-code').value;
      const btn = e.target.querySelector('button[type="submit"]');

      // Auto generate password: agentgo + username part of email
      const generatedPassword = 'agentgo' + email.split('@')[0];

      btn.innerText = 'Creating...';
      document.getElementById('add-error').innerText = '';
      document.getElementById('add-success').innerText = '';
      document.getElementById('credentials-box').classList.add('hidden');

      try {
        // Here we invoke an Edge Function to create the user by Admin
        const { data, error } = await supabase.functions.invoke('create_agent', {
          body: { email, password: generatedPassword, name, agentCode }
        });

        if (error) throw error;

        document.getElementById('add-success').innerText = 'Agent created successfully!';

        // Show credentials box
        document.getElementById('cred-email').innerText = email;
        document.getElementById('cred-password').innerText = generatedPassword;
        const mailtoBody = encodeURIComponent(`Hello ${name},\n\nYour AgentGo account has been created!\n\nEmail: ${email}\nPassword: ${generatedPassword}\n\nPlease log into the app and you can change your password from your profile settings.`);
        document.getElementById('mailto-link').href = `mailto:${email}?subject=Your AgentGo Account Credentials&body=${mailtoBody}`;
        document.getElementById('credentials-box').classList.remove('hidden');

        e.target.reset();
        loadUsers();
      } catch (err) {
        document.getElementById('add-error').innerText = err.message || 'Failed to create agent';
      } finally {
        if (btn.innerText === 'Creating...') btn.innerText = 'Create Agent';
      }
    });

    // Tab logic
    const tabs = document.querySelectorAll('.tab-link');
    const agentsView = document.getElementById('agents-view');
    const clientsView = document.getElementById('clients-view');
    const revenueView = document.getElementById('revenue-view'); // Added
    const actionsBar = document.getElementById('actions-bar');
    const pageTitle = document.getElementById('page-title');

    tabs.forEach(tab => {
      tab.addEventListener('click', (e) => {
        e.preventDefault();
        tabs.forEach(t => t.classList.remove('active'));
        tab.classList.add('active');

        const target = tab.dataset.tab;
        if (target === 'agents') {
          agentsView.classList.remove('hidden');
          clientsView.classList.add('hidden');
          revenueView.classList.add('hidden');
          actionsBar.classList.remove('hidden');
          pageTitle.innerText = 'Manage Active Agents';
          loadUsers();
        } else if (target === 'revenue') {
          agentsView.classList.add('hidden');
          clientsView.classList.add('hidden');
          revenueView.classList.remove('hidden');
          actionsBar.classList.add('hidden');
          pageTitle.innerText = 'Revenue Analysis';
          loadRevenue();
        }
      });
    });

    loadUsers();
  }
}

window.agentMap = {};

async function loadUsers() {
  const tbody = document.getElementById('users-table-body');
  if (!tbody) return;

  try {
    const { data, error } = await supabase.functions.invoke('get_agents');
    if (error) throw error;
    if (data && data.error) throw new Error(data.error);

    if (!data || !data.users || data.users.length === 0) {
      tbody.innerHTML = '<tr><td colspan="5" class="loading">No agents found</td></tr>';
      return;
    }

    const agents = data.users;
    agents.forEach(u => {
      window.agentMap[u.id] = u.user_metadata?.full_name || 'Unknown Agent';
    });

    tbody.innerHTML = agents.map(u => {
      const isCurrentAdmin = u.id === session.user.id;
      const role = u.user_metadata?.role || 'agent';

      const statusValue = u.status || 'active';
      const badgeStyle = role === 'admin'
        ? 'background: rgba(139, 92, 246, 0.15); color: #a78bfa; border-color: rgba(139, 92, 246, 0.3);'
        : (statusValue === 'deleted' ? 'background: rgba(239, 68, 68, 0.15); color: #f87171; border-color: rgba(239, 68, 68, 0.3);' : (statusValue === 'blocked' ? 'background: rgba(245, 158, 11, 0.15); color: #fbbf24; border-color: rgba(245, 158, 11, 0.3);' : 'background: rgba(16, 185, 129, 0.15); color: var(--success); border-color: rgba(16, 185, 129, 0.3);'));

      const statusText = statusValue.charAt(0).toUpperCase() + statusValue.slice(1);

      return `
        <tr class="agent-row" data-agent-id="${u.id}" data-agent-name="${u.user_metadata?.full_name || 'N/A'}" style="cursor: pointer;">
          <td>
            <strong>${u.user_metadata?.full_name || 'N/A'}</strong>
            ${isCurrentAdmin ? '<span style="font-size: 10px; background: var(--primary); color: white; padding: 2px 6px; border-radius: 4px; margin-left: 8px;">YOU</span>' : ''}
          </td>
          <td><code style="background: var(--input-bg); padding: 4px 8px; border-radius: 6px;">${u.agent_code || 'N/A'}</code></td>
          <td>${u.email}</td>
          <td>${new Date(u.created_at).toLocaleDateString()}</td>
          <td><span class="badge" style="${badgeStyle}">${statusText}</span></td>
          <td>
            <div style="display: flex; gap: 8px;" onclick="event.stopPropagation()">
              ${!isCurrentAdmin ? `
                ${statusValue !== 'deleted' ? `
                  <button class="action-btn block-btn" data-id="${u.id}" data-status="${statusValue}">
                    ${statusValue === 'blocked' ? 'Unblock' : 'Block'}
                  </button>
                ` : ''}
              ` : ''}
            </div>
          </td>
        </tr>
      `;
    }).join('');

    // Attach click listener to row
    document.querySelectorAll('.agent-row').forEach(row => {
      row.addEventListener('click', () => {
        const agentId = row.dataset.agentId;
        const agentName = row.dataset.agentName;
        showAgentClients(agentId, agentName);
      });
    });

    // Action buttons logic
    document.querySelectorAll('.block-btn').forEach(btn => {
      btn.addEventListener('click', async (e) => {
        const id = btn.dataset.id;
        const currentStatus = btn.dataset.status;
        const newStatus = currentStatus === 'blocked' ? 'active' : 'blocked';

        btn.innerText = '...';
        const { error } = await supabase.from('user').update({ status: newStatus }).eq('id', id);
        if (error) alert(error.message);
        loadUsers();
      });
    });


  } catch (e) {
    console.error(e);
    const errorMsg = e.message || 'Unknown error';
    tbody.innerHTML = `<tr><td colspan="5" class="error-msg">Could not load users: ${errorMsg}</td></tr>`;
  }
}

init();

async function loadClients(agentId = null) {
  const tbody = document.getElementById('clients-table-body');
  if (!tbody) return;
  tbody.innerHTML = '<tr><td colspan="5" class="loading">Loading clients...</td></tr>';

  try {
    let query = supabase.from('client').select('*').order('created_at', { ascending: false });

    if (agentId) {
      query = query.eq('user_id', agentId);
    }

    const { data: clients, error } = await query;

    if (error) throw error;

    if (!clients || clients.length === 0) {
      tbody.innerHTML = '<tr><td colspan="5" class="loading">No clients found</td></tr>';
      return;
    }

    tbody.innerHTML = clients.map(c => `
      <tr>
        <td><strong>${c.full_name || 'N/A'}</strong></td>
        <td><span style="font-size:14px; color:var(--text-main); font-weight:500;">${window.agentMap[c.user_id] || c.user_id || 'N/A'}</span></td>
        <td>${c.Policy_Number || 'N/A'}</td>
        <td>${c.Sum || '0'}</td>
        <td>${new Date(c.created_at).toLocaleDateString()}</td>
      </tr>
    `).join('');
  } catch (e) {
    console.error(e);
    tbody.innerHTML = '<tr><td colspan="5" class="error-msg">Could not load clients. Admin permissions required.</td></tr>';
  }
}

async function showAgentClients(agentId, agentName) {
  const tbody = document.getElementById('clients-table-body');
  const pageTitle = document.getElementById('page-title');
  tbody.innerHTML = '<tr><td colspan="5" class="loading">Loading clients...</td></tr>';

  document.getElementById('agents-view').classList.add('hidden');
  document.getElementById('clients-view').classList.remove('hidden');
  document.getElementById('revenue-view').classList.add('hidden');
  document.getElementById('actions-bar').classList.add('hidden');
  pageTitle.innerText = `Clients of ${agentName}`;

  try {
    const { data: clients, error, count } = await supabase
      .from('client')
      .select('*', { count: 'exact' })
      .eq('user_id', agentId);

    if (error) throw error;

    pageTitle.innerHTML = `Clients of ${agentName} <span style="font-size: 16px; opacity: 0.7; font-weight: 400; margin-left: 10px;">(${count || 0} Clients)</span>`;

    if (clients.length === 0) {
      tbody.innerHTML = '<tr><td colspan="5" class="loading">No clients found for this agent</td></tr>';
      return;
    }

    tbody.innerHTML = clients.map(c => `
      <tr>
        <td><strong>${c.full_name || 'N/A'}</strong></td>
        <td>${agentName}</td>
        <td>${c.Policy_Number || 'N/A'}</td>
        <td>${c.Sum || '0'}</td>
        <td>${new Date(c.created_at).toLocaleDateString()}</td>
      </tr>
    `).join('');
  } catch (e) {
    console.error(e);
    tbody.innerHTML = '<tr><td colspan="5" class="error-msg">Failed to load clients</td></tr>';
  }
}

let revenueChart = null;

async function loadRevenue() {
  const tbody = document.getElementById('revenue-table-body');
  const payoutBody = document.getElementById('payout-table-body');
  if (!tbody) return;

  try {
    // 1. Fetch Subscription Data (joining with user table for details)
    const { data: subs, subError } = await supabase
      .from('subscriptions')
      .select('*, user(name, email, stripe_customer_id)');

    if (subError) throw subError;

    // 2. Fetch Payment Records
    const { data: payments, payError } = await supabase
      .from('payments')
      .select('*, user(name)')
      .order('created_at', { ascending: false });

    if (payError) throw payError;

    // Update Stats
    const activeSubs = subs.filter(s => s.status === 'active').length;
    const totalRevenue = payments.filter(p => p.status === 'succeeded').reduce((acc, p) => acc + Number(p.amount), 0);

    document.getElementById('total-active-subs').innerText = activeSubs;
    document.getElementById('total-revenue').innerText = `₹${totalRevenue}`;

    // Wave Chart Analysis (Historical payments)
    renderRevenueChart(payments);

    if (subs.length === 0) {
      tbody.innerHTML = '<tr><td colspan="5" class="loading">No subscription data found</td></tr>';
      payoutBody.innerHTML = '<tr><td colspan="5" class="loading">No payment records found</td></tr>';
      return;
    }

    // Revenue Management Table (Payment History)
    tbody.innerHTML = payments.map(p => `
      <tr>
        <td><strong>${p.user?.name || 'N/A'}</strong></td>
        <td>Pro Monthly</td>
        <td>₹${p.amount}</td>
        <td><span class="badge" style="${p.status === 'succeeded' ? 'background: rgba(16, 185, 129, 0.1) ; color: #10b981;' : 'background: rgba(239, 68, 68, 0.1); color: #ef4444;'}">${p.status.toUpperCase()}</span></td>
        <td>${new Date(p.created_at).toLocaleDateString()}</td>
      </tr>
    `).join('');

    // Agent Payment Access Table (Active Subscriptions)
    payoutBody.innerHTML = subs.map(s => `
      <tr>
        <td><strong>${s.user?.name || s.user?.email || 'N/A'}</strong></td>
        <td style="font-family: monospace; font-size: 11px;">${s.user?.stripe_customer_id || 'Not Linked'}</td>
        <td>${s.current_period_end ? new Date(s.current_period_end).toLocaleDateString() : 'N/A'}</td>
        <td>${s.cancel_at_period_end ? 'No' : 'Yes'}</td>
        <td><button class="secondary-btn" style="padding: 4px 8px; font-size: 11px;">View Ledger</button></td>
      </tr>
    `).join('');

  } catch (e) {
    console.error('Revenue Loading Error:', e);
  }
}

function renderRevenueChart(payments) {
  const ctx = document.getElementById('revenue-chart').getContext('2d');
  if (revenueChart) revenueChart.destroy();

  // Create real data aggregation based on payments table
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const monthlyRevenue = new Array(12).fill(0);

  payments.forEach(p => {
    if (p.status === 'succeeded') {
      const date = new Date(p.created_at);
      monthlyRevenue[date.getMonth()] += Number(p.amount);
    }
  });

  const currentMonth = new Date().getMonth();
  const labelSubset = months.slice(Math.max(0, currentMonth - 5), currentMonth + 1);
  const dataPoints = monthlyRevenue.slice(Math.max(0, currentMonth - 5), currentMonth + 1);

  if (!Chart) return;

  revenueChart = new Chart(ctx, {
    type: 'line',
    data: {
      labels: labelSubset,
      datasets: [{
        label: 'Revenue (₹)',
        data: dataPoints,
        borderColor: '#8b5cf6',
        backgroundColor: 'rgba(139, 92, 246, 0.2)',
        fill: true,
        tension: 0.4,
        pointBackgroundColor: '#8b5cf6',
        pointBorderColor: '#fff',
        pointHoverRadius: 6
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { display: false }
      },
      scales: {
        y: {
          beginAtZero: true,
          grid: { color: 'rgba(255,255,255,0.05)' },
          ticks: { color: 'rgba(255,255,255,0.5)' }
        },
        x: {
          grid: { display: false },
          ticks: { color: 'rgba(255,255,255,0.5)' }
        }
      }
    }
  });
}
