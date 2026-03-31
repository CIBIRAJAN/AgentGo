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
            <a href="#" class="tab-link" data-tab="celebrations">Global Celebrations</a>
            <a href="#" class="tab-link" data-tab="plans">Manage Plans</a>
          </nav>
        </aside>
        
        <div id="sidebar-overlay" class="overlay hidden"></div>
        <main class="content">
          <header style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 30px; flex-wrap: wrap; gap: 16px;">
            <div style="display: flex; align-items: center; gap: 16px;">
              <button id="mobile-menu-toggle" class="icon-btn mobile-only" title="Menu">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="24" height="24"><path d="M4 6h16M4 12h16M4 18h16" /></svg>
              </button>
              <h1 id="page-title" style="margin-bottom: 0; font-size: clamp(20px, 5vw, 28px);">Manage Active Agents</h1>
            </div>
            <div style="display: flex; gap: 12px; align-items: center;">
              <button id="theme-toggle" class="icon-btn" title="Toggle Theme" style="display: flex; align-items: center; justify-content: center; width: 44px; height: 44px; border-radius: 12px; background: var(--input-bg); color: var(--text-main); border: 1px solid var(--border-color); cursor: pointer; transition: all 0.3s ease;">
                <svg id="theme-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="20" height="20">
                  <path id="theme-path" stroke-linecap="round" stroke-linejoin="round" d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364-6.364l-.707.707M6.343 17.657l-.707.707m12.728 0l-.707-.707M6.343 6.343l-.707-.707M12 8a4 4 0 100 8 4 4 0 000-8z" />
                </svg>
              </button>
              <button id="logout-btn" class="secondary-btn" style="height: 44px; padding: 0 15px; border-radius: 12px; display: flex; align-items: center; gap: 8px;">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><path d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" /></svg>
                <span class="desktop-only text-nowrap">Sign Out</span>
              </button>
            </div>
          </header>
          
          <div class="view" id="agents-view">
            <div class="actions" id="actions-bar" style="margin-bottom: 24px;">
              <button id="show-add-modal" class="primary-btn">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><path stroke-linecap="round" stroke-linejoin="round" d="M12 4v16m8-8H4" /></svg>
                Add New Agent
              </button>
            </div>
            <div class="card">
                <table class="data-table">
                  <thead>
                    <tr>
                      <th>Info</th>
                      <th>Name</th>
                      <th>Agent Code</th>
                      <th>Email</th>
                      <th>Created At</th>
                      <th>Status</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody id="users-table-body">
                    <tr><td colspan="7" class="loading">Loading agents...</td></tr>
                  </tbody>
                </table>
            </div>
          </div>

          <div class="view hidden" id="revenue-view">
            <div class="revenue-header" style="margin-bottom: 30px;">
              <div class="stats-grid">
                <div class="stat-card">
                  <h3>Total Revenue</h3>
                  <p id="total-revenue" class="stat-value">₹0</p>
                </div>
                <div class="stat-card">
                  <h3>Active Subscriptions</h3>
                  <p id="total-active-subs" class="stat-value">0</p>
                </div>
              </div>
              <div class="card" style="padding: 24px; margin-top: 20px;">
                <h3 style="font-size: 14px; color: var(--text-muted); text-transform: uppercase; margin-bottom: 20px;">Revenue Wave Analysis</h3>
                <div style="height: 300px; width: 100%;">
                  <canvas id="revenue-chart"></canvas>
                </div>
              </div>
            </div>

            <div style="display: grid; grid-template-columns: 1fr; gap: 30px;">
                <div class="card">
                  <div style="padding: 20px; border-bottom: 1px solid var(--border-color);"><h3 style="margin:0;">Recent Subscription Payments</h3></div>
                  <table class="data-table">
                    <thead><tr><th>Agent</th><th>Plan</th><th>Amount</th><th>Status</th><th>Date</th></tr></thead>
                    <tbody id="revenue-table-body"></tbody>
                  </table>
                </div>

                <div class="card">
                  <div style="padding: 20px; border-bottom: 1px solid var(--border-color);"><h3 style="margin:0;">Agent Payment Access</h3></div>
                  <table class="data-table">
                    <thead><tr><th>Agent</th><th>Stripe ID</th><th>Period End</th><th>Auto-Renew</th><th>Actions</th></tr></thead>
                    <tbody id="payout-table-body"></tbody>
                  </table>
                </div>
            </div>
          </div>

          <div class="view hidden" id="celebrations-view">
             <div class="view-header" style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px;">
                <h2 style="margin:0;">Global Celebrations</h2>
                <button class="primary-btn" id="show-add-celebration-modal" style="width:auto; padding:10px 20px;">+ Add Celebration</button>
             </div>
             <div class="card">
                <table class="data-table">
                    <thead><tr><th>Event Name</th><th>Date</th><th>Theme color</th><th>Image</th><th>Actions</th></tr></thead>
                    <tbody id="celebrations-table-body"></tbody>
                </table>
             </div>
          </div>

          <div class="view hidden" id="plans-view">
             <div class="view-header" style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 24px;">
                <h2 style="margin:0;">Subscription Tiers</h2>
                <button class="primary-btn" id="show-add-plan-modal" style="width:auto; padding:10px 20px;">+ Create New Plan</button>
             </div>
             <div class="card">
                <table class="data-table">
                    <thead><tr><th>Plan Tier</th><th>Monthly Price</th><th>Feature Count</th><th>Actions</th></tr></thead>
                    <tbody id="plans-table-body"></tbody>
                </table>
             </div>
          </div>

          <div class="view hidden" id="clients-view">
             <!-- Clients table -->
          </div>

          <div class="view hidden" id="agent-detail-view">
            <div style="margin-bottom: 24px;">
                <button class="secondary-btn" onclick="window.goBackToAgents()" style="display: flex; align-items: center; gap: 8px; background: var(--input-bg);">
                    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path d="M19 12H5M12 19l-7-7 7-7"/>
                    </svg>
                    Back to Agents
                </button>
            </div>
            <div class="card" style="background: linear-gradient(135deg, var(--card-bg) 0%, rgba(124, 58, 237, 0.05) 100%);">
                <div class="profile-header-container" style="padding: 32px 40px;">
                    <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 24px;">
                        <div style="display: flex; align-items: center; gap: 20px; flex-wrap: wrap;">
                            <div style="width: 64px; height: 64px; border-radius: 16px; background: var(--primary); display: flex; align-items: center; justify-content: center; color: white; font-size: 24px; font-weight: 700;" id="ad-initials-view">..</div>
                            <div style="min-width: 200px;">
                                <h2 id="ad-name-view" style="margin: 0; font-size: 24px;">...</h2>
                                <p id="ad-email-view" style="color: var(--text-muted); margin: 4px 0 0 0; word-break: break-all;"></p>
                            </div>
                        </div>
                        <div style="text-align: right; min-width: 150px;" class="ad-tier-block">
                            <span id="ad-tier-view" class="badge" style="background: var(--primary); color: white; border: none; padding: 6px 16px; border-radius: 100px;">...</span>
                            <p id="ad-code-view" style="margin: 8px 0 0 0; font-family: monospace; color: var(--text-muted);"></p>
                        </div>
                    </div>
                </div>
                
                <div class="modal-tabs" style="padding: 0 40px; overflow-x: auto; -webkit-overflow-scrolling: touch;">
                    <button class="tab-btn active" data-modaltab="info">General Info</button>
                    <button class="tab-btn" data-modaltab="stats">Platform Stats</button>
                    <button class="tab-btn" data-modaltab="billing">Billing History</button>
                    <button class="tab-btn" data-modaltab="clients">Clients</button>
                    <button class="tab-btn" data-modaltab="dues">Monthly Dues</button>
                </div>
            </div>

            <div id="agent-view-content" style="margin-top: 32px;">
                <div id="view-tab-info">
                   <div class="stats-grid" style="grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));">
                        <div class="card" style="padding: 24px;">
                            <label style="color: var(--text-muted); font-size: 12px; font-weight: 600; text-transform: uppercase; margin-bottom: 8px; display: block;">Contact Info</label>
                            <p id="ad-phone-view" style="font-size: 18px; font-weight: 600; margin-bottom: 4px;"></p>
                            <p id="ad-joined-view" style="font-size: 14px; color: var(--text-muted);"></p>
                        </div>
                        <div class="card" style="padding: 24px;">
                            <label style="color: var(--text-muted); font-size: 12px; font-weight: 600; text-transform: uppercase; margin-bottom: 8px; display: block;">Stripe Integration</label>
                            <p id="ad-stripe-view" style="font-size: 16px; font-family: monospace; color: var(--primary); word-break: break-all;"></p>
                        </div>
                        <div class="card" style="padding: 24px; display: flex; flex-direction: column; justify-content: space-between; background: rgba(239, 68, 68, 0.05); border-color: rgba(239, 68, 68, 0.1);">
                            <div>
                                <label style="color: #ef4444; font-size: 12px; font-weight: 600; text-transform: uppercase; margin-bottom: 4px; display: block;">Administrative Actions</label>
                                <p style="font-size: 13px; color: var(--text-muted); margin-bottom: 12px;">Transfer all clients from this agent to another in bulk.</p>
                            </div>
                            <button class="primary-btn" id="ad-transfer-btn-view" style="background: #ef4444; box-shadow: 0 4px 12px rgba(239, 68, 68, 0.2); width: 100%;">Transfer All Clients</button>
                        </div>
                   </div>
                </div>
                <div id="view-tab-stats" class="hidden">
                    <div class="stats-grid">
                        <div class="card" style="padding: 24px;"><h3>Calls</h3><p id="ad-calls-view">0</p></div>
                        <div class="card" style="padding: 24px;"><h3>Balance</h3><p id="ad-balance-view">0</p></div>
                        <div class="card" style="padding: 24px;"><h3>Purchases</h3><p id="ad-purchases-view">0</p></div>
                    </div>
                </div>
                <div id="view-tab-billing" class="hidden">
                    <div id="ad-billing-list-view"></div>
                </div>
                <div id="view-tab-clients" class="hidden">
                    <div id="ad-clients-list-view"></div>
                </div>
                <div id="view-tab-dues" class="hidden">
                    <div id="ad-dues-list-view"></div>
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

      <!-- Add Celebration Modal -->
      <div id="add-celebration-modal" class="modal-overlay hidden">
        <div class="modal">
          <div class="modal-header">
            <h3>Create Global Celebration</h3>
            <button id="close-celebration-modal" class="icon-btn">&times;</button>
          </div>
          <form id="add-celebration-form">
            <input type="hidden" id="edit-celeb-id" />
            <div class="input-group">
              <label>Name</label>
              <input type="text" id="new-celeb-name" placeholder="Diwali" required />
            </div>
            <div class="input-group">
              <label>Date Label</label>
              <input type="text" id="new-celeb-date" placeholder="Nov 12, 2024" required />
            </div>
            <div class="input-group">
              <label>Upload Image</label>
              <input type="file" id="new-celeb-image-file" accept="image/*" />
              <input type="hidden" id="existing-celeb-image-url" />
              <p style="font-size: 11px; margin-top: 4px; color: var(--text-muted);">Leave empty to keep existing image (if editing)</p>
            </div>
            <div class="input-group">
              <label>Theme Color Hex</label>
              <input type="text" id="new-celeb-color" placeholder="#FF5733" required />
            </div>
            <div class="form-actions">
              <button type="button" class="secondary-btn" id="cancel-celebration-modal">Cancel</button>
              <button type="submit" class="primary-btn">Create Celebration</button>
            </div>
            <p id="add-celeb-error" class="error-msg"></p>
            <p id="add-celeb-success" class="success-msg"></p>
          </form>
        </div>
      </div>

      <!-- Edit Plan Modal -->
      <div id="edit-plan-modal" class="modal-overlay hidden">
        <div class="modal">
          <div class="modal-header">
            <h3 id="plan-modal-title">Edit Subscription Plan</h3>
            <button id="close-plan-modal" class="icon-btn">&times;</button>
          </div>
          <form id="edit-plan-form">
            <input type="hidden" id="edit-plan-id" />
            <div class="input-group" id="plan-id-group">
              <label>Plan ID (Internal)</label>
              <input type="text" id="edit-plan-id-val" placeholder="e.g. ultra" />
            </div>
            <div class="input-group">
              <label>Title</label>
              <input type="text" id="edit-plan-title" required />
            </div>
            <div class="input-group">
              <label>Price Display</label>
              <input type="text" id="edit-plan-price" required />
            </div>
            <div class="input-group">
              <label>Features (JSON Array)</label>
              <textarea id="edit-plan-features" rows="4" required style="width: 100%; border-radius: 8px; border: 1px solid var(--border-color); background: var(--input-bg); color: var(--text-main); padding: 10px;"></textarea>
            </div>
            <div class="input-group">
              <label>Restricted Features (JSON Array)</label>
              <textarea id="edit-plan-restricted" rows="4" style="width: 100%; border-radius: 8px; border: 1px solid var(--border-color); background: var(--input-bg); color: var(--text-main); padding: 10px;"></textarea>
            </div>
            <div class="form-actions">
              <button type="button" class="secondary-btn" id="cancel-plan-modal">Cancel</button>
              <button type="submit" class="primary-btn" id="plan-submit-btn">Save Changes</button>
            </div>
            <p id="edit-plan-error" class="error-msg"></p>
            <p id="edit-plan-success" class="success-msg"></p>
          </form>
        </div>
      </div>
      <!-- Agent Detail Modal -->
      <div id="agent-detail-modal" class="modal-overlay hidden">
        <div class="modal large">
          <div class="modal-header">
            <h3>Agent Profile</h3>
            <button onclick="document.getElementById('agent-detail-modal').classList.add('hidden')" class="icon-btn">&times;</button>
          </div>
          <div class="modal-tabs">
            <button class="tab-btn active" data-modaltab="info">General Info</button>
            <button class="tab-btn" data-modaltab="stats">Platform Stats</button>
            <button class="tab-btn" data-modaltab="billing">Billing History</button>
            <button class="tab-btn" data-modaltab="dues">Monthly Dues</button>
          </div>
          <div id="agent-modal-content">
             <div id="agent-tab-info">
                <div class="detail-grid">
                   <div class="detail-item"><span class="detail-label">Name</span><span class="detail-value" id="ad-name"></span></div>
                   <div class="detail-item"><span class="detail-label">Email</span><span class="detail-value" id="ad-email"></span></div>
                   <div class="detail-item"><span class="detail-label">Agent Code</span><span class="detail-value" id="ad-code"></span></div>
                   <div class="detail-item"><span class="detail-label">Phone</span><span class="detail-value" id="ad-phone"></span></div>
                   <div class="detail-item"><span class="detail-label">Joined On</span><span class="detail-value" id="ad-joined"></span></div>
                   <div class="detail-item"><span class="detail-label">Plan Tier</span><span class="detail-value" id="ad-tier"></span></div>
                </div>
             </div>
             <div id="agent-tab-stats" class="hidden">
                 <div class="stats-mini-grid">
                    <div class="stat-mini-card"><span class="val" id="ad-calls">0</span><span class="lab">Auto Calls</span></div>
                    <div class="stat-mini-card"><span class="val" id="ad-balance">0</span><span class="lab">Call Balance</span></div>
                    <div class="stat-mini-card"><span class="val" id="ad-purchases">0</span><span class="lab">Purchases</span></div>
                 </div>
             </div>
             <div id="agent-tab-billing" class="hidden">
                 <div id="ad-billing-list" style="margin-top:20px;"></div>
             </div>
             <div id="agent-tab-dues" class="hidden">
                 <div id="ad-dues-list" style="margin-top:20px;"></div>
             </div>
          </div>
        </div>
      </div>

      <!-- Client Detail Modal -->
      <div id="client-detail-modal" class="modal-overlay hidden">
        <div class="modal">
          <div class="modal-header">
            <h3>Client Information</h3>
            <button onclick="document.getElementById('client-detail-modal').classList.add('hidden')" class="icon-btn">&times;</button>
          </div>
          <div class="detail-grid" style="grid-template-columns: 1fr 1fr;">
              <div class="detail-item"><span class="detail-label">Name</span><span class="detail-value" id="cd-name"></span></div>
              <div class="detail-item"><span class="detail-label">Policy</span><span class="detail-value" id="cd-policy"></span></div>
              <div class="detail-item"><span class="detail-label">Sum Assured</span><span class="detail-value" id="cd-sum"></span></div>
              <div class="detail-item"><span class="detail-label">Mode</span><span class="detail-value" id="cd-mode"></span></div>
              <div class="detail-item"><span class="detail-label">Premium</span><span class="detail-value" id="cd-premium"></span></div>
              <div class="detail-item"><span class="detail-label">Term</span><span class="detail-value" id="cd-term"></span></div>
              <div class="detail-item"><span class="detail-label">Mobile</span><span class="detail-value" id="cd-mobile"></span></div>
              <div class="detail-item"><span class="detail-label">Assigned To</span><span class="detail-value" id="cd-agent"></span></div>
          </div>
          <div style="margin-top: 30px;">
              <button class="primary-btn" id="show-reassign-btn">Transfer Client to Agent</button>
          </div>
        </div>
      </div>

      <!-- Transfer Client Modal -->
      <div id="reassign-modal" class="modal-overlay hidden" style="z-index: 110;">
        <div class="modal">
          <div class="modal-header">
            <h3>Transfer Client</h3>
            <button onclick="document.getElementById('reassign-modal').classList.add('hidden')" class="icon-btn">&times;</button>
          </div>
          <div class="info-banner">
             <p>Reassigning <strong><span id="reassign-client-name"></span></strong></p>
          </div>
          <div class="input-group">
              <label>Search Agent</label>
              <input type="text" id="agent-search-input" placeholder="Search by name or code..." style="width:100%; border-radius:10px; margin-bottom: 10px;">
              <label>Select New Agent</label>
              <select id="new-agent-select" style="width:100%; padding:12px; border-radius:10px; background:var(--input-bg); border:1px solid var(--border-color); color:var(--text-main); font-family:inherit;">
              </select>
          </div>
          <div class="form-actions">
              <button class="secondary-btn" onclick="document.getElementById('reassign-modal').classList.add('hidden')">Cancel</button>
              <button class="primary-btn" id="confirm-reassign-btn">Confirm Transfer</button>
          </div>
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

    // Modal logic for Celebrations
    const celebModal = document.getElementById('add-celebration-modal');
    document.getElementById('show-add-celebration-modal').addEventListener('click', () => {
      document.getElementById('add-celeb-error').innerText = '';
      document.getElementById('add-celeb-success').innerText = '';
      document.getElementById('edit-celeb-id').value = '';
      document.getElementById('existing-celeb-image-url').value = '';
      document.getElementById('add-celebration-form').querySelector('button[type="submit"]').innerText = 'Create Celebration';
      document.querySelector('#add-celebration-modal h3').innerText = 'Create Global Celebration';
      celebModal.classList.remove('hidden');
    });

    document.getElementById('show-add-plan-modal').addEventListener('click', () => {
        document.getElementById('edit-plan-form').reset();
        document.getElementById('edit-plan-id').value = '';
        document.getElementById('plan-id-group').classList.remove('hidden');
        document.getElementById('plan-modal-title').innerText = 'Create New Plan';
        document.getElementById('plan-submit-btn').innerText = 'Create Plan';
        document.getElementById('edit-plan-modal').classList.remove('hidden');
    });
    const closeCelebModal = () => celebModal.classList.add('hidden');
    document.getElementById('close-celebration-modal').addEventListener('click', closeCelebModal);
    document.getElementById('cancel-celebration-modal').addEventListener('click', closeCelebModal);

    // Modal logic for Plans
    const planModal = document.getElementById('edit-plan-modal');
    const closePlanModal = () => planModal.classList.add('hidden');
    document.getElementById('close-plan-modal').addEventListener('click', closePlanModal);
    document.getElementById('cancel-plan-modal').addEventListener('click', closePlanModal);

    document.getElementById('edit-plan-form').addEventListener('submit', async (e) => {
      e.preventDefault();
      const id = document.getElementById('edit-plan-id').value;
      const title = document.getElementById('edit-plan-title').value;
      const price = document.getElementById('edit-plan-price').value;
      const featuresStr = document.getElementById('edit-plan-features').value;
      const restrictedStr = document.getElementById('edit-plan-restricted').value;

      const btn = e.target.querySelector('button[type="submit"]');
      try {
        let features, restrictedFeatures;
        try {
          features = JSON.parse(featuresStr || '[]');
          restrictedFeatures = JSON.parse(restrictedStr || '[]');
        } catch (err) {
          throw new Error('Invalid JSON format for features or restricted features');
        }

        if (id) {
            const { error } = await supabase.from('subscription_plans').update({
              title, price, features, restricted_features: restrictedFeatures
            }).eq('id', id);
            if (error) throw error;
        } else {
            const newId = document.getElementById('edit-plan-id-val').value;
            if (!newId) throw new Error("Plan ID is required for new plans");
            const { error } = await supabase.from('subscription_plans').insert({
              id: newId.toLowerCase(), title, price, features, restricted_features: restrictedFeatures
            });
            if (error) throw error;
        }

        document.getElementById('edit-plan-success').innerText = 'Plan saved successfully!';
        loadPlans();
        setTimeout(() => closePlanModal(), 1500);
      } catch (err) {
        document.getElementById('edit-plan-error').innerText = err.message || 'Failed to save plan';
      } finally {
        if (btn.innerText.includes('Saving') || btn.innerText.includes('Creating')) {
            btn.innerText = id ? 'Save Changes' : 'Create Plan';
        }
      }
    });

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

    document.getElementById('add-celebration-form').addEventListener('submit', async (e) => {
      e.preventDefault();
      const name = document.getElementById('new-celeb-name').value;
      const date = document.getElementById('new-celeb-date').value;
      const fileInput = document.getElementById('new-celeb-image-file');
      const celebId = document.getElementById('edit-celeb-id').value;
      let imageUrl = document.getElementById('existing-celeb-image-url').value;
      let colorHex = document.getElementById('new-celeb-color').value;

      if (!colorHex.startsWith('#')) {
        colorHex = '#' + colorHex;
      }
      
      const btn = e.target.querySelector('button[type="submit"]');
      const originalBtnText = btn.innerText;
      btn.innerText = celebId ? 'Updating...' : 'Creating...';
      document.getElementById('add-celeb-error').innerText = '';
      document.getElementById('add-celeb-success').innerText = '';

      try {
        // Handle file upload if present
        if (fileInput.files.length > 0) {
            const file = fileInput.files[0];
            const fileExt = file.name.split('.').pop();
            const fileName = `${Math.random().toString(36).substring(2)}.${fileExt}`;
            const filePath = `${fileName}`;

            const { error: uploadError } = await supabase.storage
                .from('global-celebrations')
                .upload(filePath, file);

            if (uploadError) throw uploadError;

            const { data: { publicUrl } } = supabase.storage
                .from('global-celebrations')
                .getPublicUrl(filePath);
            
            imageUrl = publicUrl;
        }

        if (!imageUrl && !celebId) {
            throw new Error("Image is required for new celebrations");
        }

        const payload = {
          name: name,
          date: date,
          image_url: imageUrl,
          theme_color_hex: colorHex
        };

        if (celebId) {
            const { error } = await supabase.from('global_celebrations').update(payload).eq('id', celebId);
            if (error) throw error;
            document.getElementById('add-celeb-success').innerText = 'Celebration updated successfully!';
        } else {
            const { error } = await supabase.from('global_celebrations').insert(payload);
            if (error) throw error;
            document.getElementById('add-celeb-success').innerText = 'Celebration created successfully!';
        }

        e.target.reset();
        loadCelebrations();
        
        // auto-close after 1.5 seconds
        setTimeout(() => closeCelebModal(), 1500);
      } catch (err) {
        document.getElementById('add-celeb-error').innerText = err.message || 'Failed to save celebration';
      } finally {
        btn.innerText = originalBtnText;
      }
    });

    // Agent Detail Modal Tab Switching
    document.querySelectorAll('.tab-btn[data-modaltab]').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const modal = btn.closest('.modal');
        const target = btn.dataset.modaltab;
        
        modal.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        
        const tabs = ['info', 'stats', 'billing'];
        tabs.forEach(t => {
          const content = document.getElementById(`agent-tab-${t}`);
          if (content) content.classList.toggle('hidden', t !== target);
        });
      });
    });

    // Handle Hash Routing
    function handleNavigation() {
      const hash = window.location.hash || '#agents';
      const [view, id] = hash.substring(1).split('/');
      
      const tabs = document.querySelectorAll('.tab-link');
      const views = {
        'agents': document.getElementById('agents-view'),
        'revenue': document.getElementById('revenue-view'),
        'celebrations': document.getElementById('celebrations-view'),
        'plans': document.getElementById('plans-view'),
        'clients': document.getElementById('clients-view'),
        'agent-detail': document.getElementById('agent-detail-view')
      };

      const actionsBar = document.getElementById('actions-bar');
      const pageTitle = document.getElementById('page-title');

      // Hide all views first
      Object.values(views).forEach(v => v && v.classList.add('hidden'));
      actionsBar.classList.add('hidden');
      tabs.forEach(t => t.classList.remove('active'));

      if (view === 'agent-detail' && id) {
          window.openAgentDetail(id);
      } else {
        const currentView = views[view] || views['agents'];
        if (currentView) currentView.classList.remove('hidden');
        
        const activeTab = document.querySelector(`.tab-link[data-tab="${view}"]`);
        if (activeTab) activeTab.classList.add('active');

        if (view === 'agents') {
            actionsBar.classList.remove('hidden');
            pageTitle.innerText = 'Manage Active Agents';
            loadUsers();
        } else if (view === 'revenue') {
            pageTitle.innerText = 'Revenue Analysis';
            loadRevenue();
        } else if (view === 'celebrations') {
            pageTitle.innerText = 'Global Celebrations';
            loadCelebrations();
        } else if (view === 'plans') {
            pageTitle.innerText = 'Manage Subscriptions & Pricing';
            loadPlans();
        }
      }
    }

    // Set up tab click to update hash
    document.querySelectorAll('.tab-link').forEach(tab => {
        tab.addEventListener('click', (e) => {
            e.preventDefault();
            window.location.hash = tab.dataset.tab;
        });
    });

    window.addEventListener('hashchange', handleNavigation);
    handleNavigation(); // Initial load

    // Mobile Sidebar Toggle
    const sidebar = document.querySelector('.sidebar');
    const overlay = document.getElementById('sidebar-overlay');
    const toggle = document.getElementById('mobile-menu-toggle');

    if (toggle) {
        toggle.addEventListener('click', () => {
            sidebar.classList.toggle('active');
            overlay.classList.toggle('hidden');
        });
    }

    if (overlay) {
        overlay.addEventListener('click', () => {
            sidebar.classList.remove('active');
            overlay.classList.add('hidden');
        });
    }

    // Auto-close sidebar on menu click on mobile
    document.querySelectorAll('.tab-link').forEach(link => {
        link.addEventListener('click', () => {
            if (window.innerWidth <= 1024) {
                sidebar.classList.remove('active');
                overlay.classList.add('hidden');
            }
        });
    });
  }
}

window.openAgentDetail = async function(id) {
    if (window.location.hash !== `#agent-detail/${id}`) {
        window.location.hash = `agent-detail/${id}`;
        return;
    }
    const agentsView = document.getElementById('agents-view');
    const detailView = document.getElementById('agent-detail-view');
    const actionsBar = document.getElementById('actions-bar');
    const pageTitle = document.getElementById('page-title');

    agentsView.classList.add('hidden');
    actionsBar.classList.add('hidden');
    detailView.classList.remove('hidden');
    pageTitle.innerText = 'Agent Deep Dive';

    // Set up tabs inside the view
    detailView.querySelectorAll('.tab-btn').forEach(btn => {
        btn.onclick = () => {
            const target = btn.dataset.modaltab;
            detailView.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            ['info', 'stats', 'billing', 'clients', 'dues'].forEach(t => {
                const content = document.getElementById(`view-tab-${t}`);
                if (content) content.classList.toggle('hidden', t !== target);
            });
        };
    });

    // Reset to first tab
    detailView.querySelector('[data-modaltab="info"]').click();

    try {
        const { data: user, error: userError } = await supabase.from('user').select('*').eq('id', id).single();
        if (userError) throw userError;

        document.getElementById('ad-name-view').innerText = user.name || 'N/A';
        document.getElementById('ad-email-view').innerText = user.email || 'N/A';
        document.getElementById('ad-code-view').innerText = user.agent_code || 'N/A';
        document.getElementById('ad-phone-view').innerText = user.phone_number || 'N/A';
        document.getElementById('ad-joined-view').innerText = `Member since ${new Date(user.created_at).toLocaleDateString()}`;
        document.getElementById('ad-tier-view').innerText = (user.plan_tier || 'base').toUpperCase();
        document.getElementById('ad-stripe-view').innerText = user.stripe_customer_id || 'Not Linked to Stripe';
        document.getElementById('ad-initials-view').innerText = (user.name || 'A').charAt(0).toUpperCase();

        document.getElementById('ad-transfer-btn-view').onclick = () => window.openTransferAll(user.id, user.name);

        const { count: callCount } = await supabase.from('call_logs').select('*', { count: 'exact', head: true }).eq('user_id', id);
        document.getElementById('ad-calls-view').innerText = callCount || 0;
        document.getElementById('ad-balance-view').innerText = user.call_points_balance || 0;

        const { data: payments } = await supabase.from('payments').select('*').eq('user_id', id).order('created_at', { ascending: false });
        document.getElementById('ad-purchases-view').innerText = payments?.length || 0;

        const billingList = document.getElementById('ad-billing-list-view');
        if (!payments || payments.length === 0) {
            billingList.innerHTML = '<div class="card" style="padding:40px; text-align:center; color:var(--text-muted);">No payment records found.</div>';
        } else {
            billingList.innerHTML = `
                <div class="card" style="padding:0; overflow:hidden;">
                    <table class="data-table">
                        <thead>
                            <tr>
                                <th style="padding-left: 32px;">Date</th>
                                <th>Amount</th>
                                <th>Status</th>
                                <th style="padding-right: 32px;">Reference</th>
                            </tr>
                        </thead>
                        <tbody>
                            ${payments.map(p => `
                                <tr>
                                    <td style="padding-left: 32px;">${new Date(p.created_at).toLocaleDateString()}</td>
                                    <td style="font-weight:600; color:var(--primary);">₹${Number(p.amount).toLocaleString()}</td>
                                    <td><span class="badge" style="background:rgba(16,185,129,0.1); color:#10b981; border:none;">${p.status.toUpperCase()}</span></td>
                                    <td style="padding-right: 32px; font-family:monospace; font-size:11px; opacity:0.6;">${p.stripe_payment_intent_id || 'N/A'}</td>
                                </tr>
                            `).join('')}
                        </tbody>
                    </table>
                </div>
            `;
        }

        // Fetch Clients
        const { data: qClients } = await supabase.from('client').select('*').eq('user_id', id).order('full_name');
        const clientsListView = document.getElementById('ad-clients-list-view');
        if (!qClients || qClients.length === 0) {
            clientsListView.innerHTML = '<div class="card" style="padding:40px; text-align:center; color:var(--text-muted);">No clients assigned to this agent.</div>';
        } else {
            clientsListView.innerHTML = `
                <div class="card" style="padding:0; overflow:hidden;">
                    <table class="data-table">
                        <thead>
                            <tr>
                                <th style="padding-left: 32px;">Client Name</th>
                                <th>Policy Number</th>
                                <th>Premium</th>
                                <th>Mode</th>
                                <th style="padding-right: 32px;">Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            ${qClients.map(c => `
                                <tr>
                                    <td style="padding-left: 32px;"><strong>${c.full_name || 'N/A'}</strong></td>
                                    <td><code style="font-size:11px; background: var(--input-bg); padding: 4px 8px; border-radius: 4px;">${c.Policy_Number || 'N/A'}</code></td>
                                    <td style="font-weight:600;">₹${c.Premium ? Number(c.Premium.replace(/[^0-9.]/g, '')).toLocaleString('en-IN') : 'N/A'}</td>
                                    <td>${c.Mode || 'N/A'}</td>
                                    <td style="padding-right: 32px;">
                                        <button class="eye-btn" onclick="window.openClientDetail('${c.id}')" title="View Details" style="width: 32px; height: 32px;">
                                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="16" height="16"><path d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /><path d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" /></svg>
                                        </button>
                                    </td>
                                </tr>
                            `).join('')}
                        </tbody>
                    </table>
                </div>
            `;
        }

        // Fetch Monthly Dues - Show ALL statuses to help admin see history
        const { data: dues } = await supabase.from('monthly_dues').select('*').eq('user_id', id).order('due_month', { ascending: false });
        const duesList = document.getElementById('ad-dues-list-view');
        
        if (!dues || dues.length === 0) {
            duesList.innerHTML = '<div class="card" style="padding:40px; text-align:center; color:var(--text-muted);">No dues records found for this agent.</div>';
        } else {
            const grouped = {};
            dues.forEach(d => {
                const dateStr = (d.due_month && d.due_month.length === 7) ? d.due_month + "-01" : d.due_month;
                const monthName = dateStr ? new Date(dateStr).toLocaleString('default', { month: 'long', year: 'numeric' }) : 'Unknown Date';
                if(!grouped[monthName]) grouped[monthName] = [];
                grouped[monthName].push(d);
            });

            const uniqueMonths = Object.keys(grouped);
            const currentMonth = uniqueMonths[0]; // Most recent

            duesList.innerHTML = `
                <div class="card" style="padding: 24px; margin-bottom: 24px; display: flex; justify-content: space-between; align-items: center; background: rgba(124, 58, 237, 0.05);">
                    <div>
                        <h4 style="margin:0; color:var(--primary);">Dues by Month</h4>
                        <p style="margin:4px 0 0 0; font-size:13px; color:var(--text-muted);">Select a month to view detailed client dues</p>
                    </div>
                    <select id="ad-dues-month-selector" style="padding: 10px 16px; border-radius: 10px; background: var(--input-bg); border: 1px solid var(--border-color); color: var(--text-main); font-family: inherit; cursor: pointer; min-width: 200px;">
                        ${uniqueMonths.map(m => `<option value="${m}">${m}</option>`).join('')}
                    </select>
                </div>
                <div id="ad-dues-table-container"></div>
            `;

            const renderMonthDues = (month) => {
                const monthDues = grouped[month];
                document.getElementById('ad-dues-table-container').innerHTML = `
                    <div class="card" style="padding:0; overflow: hidden;">
                        <table class="data-table">
                            <thead>
                                <tr>
                                    <th style="padding-left: 32px;">Client Name</th>
                                    <th style="padding-left: 32px;">Policy Number</th>
                                    <th>Premium Amount</th>
                                    <th>Due Date</th>
                                    <th style="padding-right: 32px;">Status</th>
                                </tr>
                            </thead>
                            <tbody>
                                ${monthDues.map(d => `
                                    <tr>
                                        <td style="padding-left: 32px;"><strong>${d.customer_name || 'N/A'}</strong></td>
                                        <td style="padding-left: 32px;"><code style="font-size:11px; background: var(--input-bg); padding: 4px 8px; border-radius: 4px;">${d.policy_number}</code></td>
                                        <td style="font-weight: 600;">₹${Number(d.premium_amount || 0).toLocaleString('en-IN')}</td>
                                        <td>${d.due_date ? new Date(d.due_date).toLocaleDateString() : 'N/A'}</td>
                                        <td style="padding-right: 32px;">
                                            <span class="badge" style="${
                                                d.status === 'paid' ? 'background:rgba(16,185,129,0.1); color:#10b981;' : 
                                                d.status === 'overdue' ? 'background:rgba(239,68,68,0.1); color:#ef4444;' :
                                                'background:rgba(245,158,11,0.1); color:#f59e0b;'
                                            } border:none;">${d.status.toUpperCase()}</span>
                                        </td>
                                    </tr>
                                `).join('')}
                            </tbody>
                        </table>
                    </div>
                `;
            };

            renderMonthDues(currentMonth);
            document.getElementById('ad-dues-month-selector').onchange = (e) => renderMonthDues(e.target.value);
        }
    } catch(err) {
        console.error("AgentDetail Error:", err);
        detailView.innerHTML = `<div class="card" style="padding:40px; text-align:center;"><h3>Error loading agent details</h3><p>${err.message}</p><button class="secondary-btn" onclick="window.goBackToAgents()">Go Back</button></div>`;
    }
};

window.openClientDetail = async function(id) {
    const modal = document.getElementById('client-detail-modal');
    modal.classList.remove('hidden');

    try {
        const { data: client, error } = await supabase.from('client').select('*, user(name)').eq('id', id).single();
        if (error) throw error;

        document.getElementById('cd-name').innerText = client.full_name || 'N/A';
        document.getElementById('cd-policy').innerText = client.Policy_Number || 'N/A';
        document.getElementById('cd-sum').innerText = client.Sum ? `₹${Number(client.Sum.replace(/[^0-9.]/g, '')).toLocaleString('en-IN')}` : '₹0';
        document.getElementById('cd-mode').innerText = client.Mode || 'N/A';
        document.getElementById('cd-premium').innerText = client.Premium ? `₹${Number(client.Premium.replace(/[^0-9.]/g, '')).toLocaleString('en-IN')}` : '₹0';
        document.getElementById('cd-term').innerText = client.Term || 'N/A';
        document.getElementById('cd-mobile').innerText = `${client.mobile_number_cc || '+91'}${client.mobile_number || ''}`;
        document.getElementById('cd-agent').innerText = client.user?.name || 'N/A';

        document.getElementById('show-reassign-btn').onclick = () => window.openReassign(client.id, client.full_name);
    } catch(err) {
        console.error(err);
    }
};

window.openReassign = async function(clientId, clientName) {
    const modal = document.getElementById('reassign-modal');
    document.getElementById('reassign-client-name').innerText = clientName;
    modal.classList.remove('hidden');

    try {
        const { data } = await supabase.functions.invoke('get_agents');
        const agents = data.users;
        const select = document.getElementById('new-agent-select');
        select.innerHTML = agents.map(u => `
            <option value="${u.id}">${u.user_metadata?.full_name || u.email} (${u.agent_code || 'No Code'})</option>
        `).join('');

        document.getElementById('confirm-reassign-btn').onclick = async () => {
            const newAgentId = select.value;
            const { error: upError } = await supabase.from('client').update({ user_id: newAgentId }).eq('id', clientId);
            if (!upError) {
                alert("Client transferred successfully!");
                modal.classList.add('hidden');
                document.getElementById('client-detail-modal').classList.add('hidden');
                loadUsers();
            }
        };
    } catch(err) {
        console.error(err);
    }
};

// Original Tab Logic continuation below...


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
            <button class="eye-btn" onclick="event.stopPropagation(); window.openAgentDetail('${u.id}')">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" width="16" height="16"><path d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" /><path d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" /></svg>
            </button>
          </td>
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
      <tr onclick="window.openClientDetail('${c.id}')" style="cursor: pointer;">
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
  document.getElementById('plans-view').classList.add('hidden');
  document.getElementById('celebrations-view').classList.add('hidden');
  document.getElementById('actions-bar').classList.remove('hidden');

  const backBtn = `
    <button onclick="window.goBackToAgents()" class="icon-btn" style="margin-right: 15px; background: var(--input-bg); border: 1px solid var(--border-color); width: 36px; height: 36px; border-radius: 10px; display: inline-flex; align-items: center; justify-content: center; vertical-align: middle; cursor: pointer; color: var(--text-main);">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" width="18" height="18"><path d="M19 12H5M12 19l-7-7 7-7"/></svg>
    </button>
  `;
  
  const actionsBar = document.getElementById('actions-bar');
  actionsBar.innerHTML = `
    <div style="display: flex; gap: 12px; width: 100%; justify-content: flex-end;">
      <button onclick="window.openTransferAll('${agentId}', '${agentName}')" class="primary-btn warning-btn">
        Transfer All Clients
      </button>
    </div>
  `;

  pageTitle.innerHTML = `${backBtn} <span>Clients of ${agentName}</span>`;

  try {
    const { data: clients, error, count } = await supabase
      .from('client')
      .select('*', { count: 'exact' })
      .eq('user_id', agentId);

    if (error) throw error;

    pageTitle.innerHTML = `${backBtn} <span>Clients of ${agentName} <span style="font-size: 16px; opacity: 0.7; font-weight: 400; margin-left: 10px;">(${count || 0} Clients)</span></span>`;

    if (clients.length === 0) {
      tbody.innerHTML = '<tr><td colspan="5" class="loading">No clients found for this agent</td></tr>';
      return;
    }

    tbody.innerHTML = clients.map(c => `
      <tr onclick="window.openClientDetail('${c.id}')" style="cursor: pointer;">
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
    document.getElementById('total-revenue').innerText = `₹${totalRevenue.toLocaleString('en-IN')}`;

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
        <td>₹${Number(p.amount).toLocaleString('en-IN')}</td>
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
        <td><button class="secondary-btn" style="padding: 4px 8px; font-size: 11px;" onclick="window.openAgentDetail('${s.user_id}')">View Profile</button></td>
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

// Ensure function is exposed globally
window.deleteCelebration = async function(id) {
  if (!confirm('Are you sure you want to delete this celebration?')) return;
  const { error } = await supabase.from('global_celebrations').delete().eq('id', id);
  if (error) alert(error.message);
  loadCelebrations();
};

async function loadCelebrations() {
  const tbody = document.getElementById('celebrations-table-body');
  if (!tbody) return;
  tbody.innerHTML = '<tr><td colspan="5" class="loading">Loading celebrations...</td></tr>';

  try {
    const { data: celebrations, error } = await supabase
      .from('global_celebrations')
      .select('*')
      .order('name');

    if (error) throw error;

    if (!celebrations || celebrations.length === 0) {
      tbody.innerHTML = '<tr><td colspan="5" class="loading">No celebrations found</td></tr>';
      return;
    }

    tbody.innerHTML = celebrations.map(c => `
      <tr>
        <td><strong>${c.name}</strong></td>
        <td>${c.date}</td>
        <td>
          <div style="display: flex; align-items: center; gap: 8px;">
            <div style="width: 20px; height: 20px; border-radius: 4px; background: ${c.theme_color_hex}"></div>
            ${c.theme_color_hex}
          </div>
        </td>
        <td>
          <img src="${c.image_url}" alt="${c.name}" style="width: 60px; height: 40px; border-radius: 4px; object-fit: cover;" />
        </td>
        <td>
          <div style="display: flex; gap: 8px;">
            <button class="secondary-btn" onclick="window.openEditCelebration('${c.id}')" style="font-size: 11px; padding: 4px 8px;">Edit</button>
            <button class="secondary-btn" onclick="window.deleteCelebration('${c.id}')" style="color: #ef4444; border-color: rgba(239, 68, 68, 0.3); font-size: 11px; padding: 4px 8px;">Delete</button>
          </div>
        </td>
      </tr>
    `).join('');
  } catch (e) {
    console.error(e);
    tbody.innerHTML = '<tr><td colspan="5" class="error-msg">Failed to load celebrations</td></tr>';
  }
}

window.openEditPlan = async function(id) {
  try {
    const { data: plan, error } = await supabase.from('subscription_plans').select('*').eq('id', id).single();
    if (error) throw error;
    
    document.getElementById('edit-plan-id').value = plan.id;
    document.getElementById('edit-plan-id-val').value = plan.id;
    document.getElementById('plan-id-group').classList.add('hidden'); // Cannot change ID of existing plan
    document.getElementById('edit-plan-title').value = plan.title;
    document.getElementById('edit-plan-price').value = plan.price;
    document.getElementById('edit-plan-features').value = JSON.stringify(plan.features, null, 2);
    document.getElementById('edit-plan-restricted').value = JSON.stringify(plan.restricted_features, null, 2);
    
    document.getElementById('plan-modal-title').innerText = 'Edit Subscription Plan';
    document.getElementById('plan-submit-btn').innerText = 'Save Changes';
    document.getElementById('edit-plan-error').innerText = '';
    document.getElementById('edit-plan-success').innerText = '';
    document.getElementById('edit-plan-modal').classList.remove('hidden');
  } catch(e) {
    alert("Error loading plan details: " + e.message);
  }
};

window.openEditCelebration = async function(id) {
  try {
    const { data: c, error } = await supabase.from('global_celebrations').select('*').eq('id', id).single();
    if (error) throw error;
    
    document.getElementById('edit-celeb-id').value = c.id;
    document.getElementById('new-celeb-name').value = c.name;
    document.getElementById('new-celeb-date').value = c.date;
    document.getElementById('new-celeb-color').value = c.theme_color_hex;
    document.getElementById('existing-celeb-image-url').value = c.image_url;
    
    document.getElementById('add-celeb-error').innerText = '';
    document.getElementById('add-celeb-success').innerText = '';
    document.getElementById('add-celebration-form').querySelector('button[type="submit"]').innerText = 'Update Celebration';
    document.querySelector('#add-celebration-modal h3').innerText = 'Edit Global Celebration';
    document.getElementById('add-celebration-modal').classList.remove('hidden');
  } catch(e) {
    alert("Error loading celebration details: " + e.message);
  }
};

async function loadPlans() {
  const tbody = document.getElementById('plans-table-body');
  if (!tbody) return;
  tbody.innerHTML = '<tr><td colspan="4" class="loading">Loading plans...</td></tr>';

  try {
    const { data: plans, error } = await supabase
      .from('subscription_plans')
      .select('*');
    if (error) throw error;

    if (!plans || plans.length === 0) {
      tbody.innerHTML = '<tr><td colspan="4" class="loading">No plans found</td></tr>';
      return;
    }

    const order = { 'base': 1, 'mid': 2, 'premium': 3 };
    plans.sort((a,b) => (order[a.id] || 99) - (order[b.id] || 99));

    tbody.innerHTML = plans.map(p => `
      <tr>
        <td><strong>${p.title}</strong><br><small style="color:var(--text-muted);">${p.id.toUpperCase()}</small></td>
        <td><span style="font-size:16px; font-weight:700; color:var(--primary);">₹${Number(p.price.replace(/[^0-9.]/g, '')).toLocaleString('en-IN')}</span></td>
        <td>${p.features.length} Features</td>
        <td>
          <button class="secondary-btn" onclick="window.openEditPlan('${p.id}')">Edit Plan</button>
        </td>
      </tr>
    `).join('');
  } catch (e) {
    console.error(e);
    tbody.innerHTML = '<tr><td colspan="4" class="error-msg">Failed to load plans</td></tr>';
  }
}


window.goBackToAgents = function() {
    window.location.hash = 'agents';
};

window.openTransferAll = async function(sourceAgentId, sourceAgentName) {
    const modal = document.getElementById('reassign-modal');
    document.getElementById('reassign-client-name').innerText = `ALL Clients of ${sourceAgentName}`;
    modal.classList.remove('hidden');

    try {
        const { data } = await supabase.functions.invoke('get_agents');
        const agents = data.users.filter(u => u.id !== sourceAgentId); // Don't transfer to self

        const select = document.getElementById('new-agent-select');
        const renderAgents = (filtered) => {
            select.innerHTML = filtered.map(u => `
                <option value="${u.id}">${u.user_metadata?.full_name || u.email} (${u.agent_code || 'No Code'})</option>
            `).join('');
        };

        renderAgents(agents);

        // Search logic
        const searchInput = document.getElementById('agent-search-input');
        searchInput.value = '';
        searchInput.oninput = (e) => {
            const query = e.target.value.toLowerCase();
            const filtered = agents.filter(u => 
                (u.user_metadata?.full_name || '').toLowerCase().includes(query) || 
                (u.email || '').toLowerCase().includes(query) ||
                (u.agent_code || '').toLowerCase().includes(query)
            );
            renderAgents(filtered);
        };

        document.getElementById('confirm-reassign-btn').onclick = async () => {
            if (!confirm(`Are you sure you want to transfer ALL data from ${sourceAgentName} to the selected agent? This includes all clients, dues, call logs, WhatsApp records, and PDFs.`)) return;
            
            const newAgentId = select.value;
            const btn = document.getElementById('confirm-reassign-btn');
            const originalText = btn.innerText;
            btn.innerText = 'Transferring Everything...';
            btn.disabled = true;
            
            try {
                // Update all identifying tables
                const updateTargets = [
                    { table: 'client', field: 'user_id' },
                    { table: 'monthly_dues', field: 'user_id' },
                    { table: 'call_logs', field: 'user_id' },
                    { table: 'pdf_uploads', field: 'user_id' },
                    { table: 'pdf_modification', field: 'user_id' },
                    { table: 'reminders', field: 'user_id' },
                    { table: 'commission_records', field: 'user_id' },
                    { table: 'commission_uploads', field: 'user_id' },
                    { table: 'payments', field: 'user_id' },
                    { table: 'subscriptions', field: 'user_id' },
                    { table: 'notifications', field: 'user_id' },
                    { table: 'user_devices', field: 'user_id' },
                    { table: 'agent_diary', field: 'user_id' },
                    { table: 'family_members', field: 'user_id' }
                ];

                for (const target of updateTargets) {
                    await supabase.from(target.table).update({ [target.field]: newAgentId }).eq(target.field, sourceAgentId);
                }

                // Handle agent connections (manager and owner)
                await supabase.from('agent_connections').update({ manager_id: newAgentId }).eq('manager_id', sourceAgentId);
                await supabase.from('agent_connections').update({ owner_id: newAgentId }).eq('owner_id', sourceAgentId);

                alert("Agent's entire ecosystem transferred successfully!");
                modal.classList.add('hidden');
                goBackToAgents();
            } catch (err) {
                alert("Partial transfer failure: " + err.message);
                console.error(err);
            } finally {
                btn.innerText = originalText;
                btn.disabled = false;
            }
        };

    } catch(err) {
        alert("Error loading agents: " + err.message);
    }
};

// Update standard openReassign to use search too
const originalOpenReassign = window.openReassign;
window.openReassign = async function(clientId, clientName) {
    const modal = document.getElementById('reassign-modal');
    document.getElementById('reassign-client-name').innerText = clientName;
    modal.classList.remove('hidden');

    try {
        const { data } = await supabase.functions.invoke('get_agents');
        const agents = data.users;

        const select = document.getElementById('new-agent-select');
        const renderAgents = (filtered) => {
            select.innerHTML = filtered.map(u => `
                <option value="${u.id}">${u.user_metadata?.full_name || u.email} (${u.agent_code || 'No Code'})</option>
            `).join('');
        };

        renderAgents(agents);

        const searchInput = document.getElementById('agent-search-input');
        searchInput.value = '';
        searchInput.oninput = (e) => {
            const query = e.target.value.toLowerCase();
            const filtered = agents.filter(u => 
                (u.user_metadata?.full_name || '').toLowerCase().includes(query) || 
                (u.email || '').toLowerCase().includes(query) ||
                (u.agent_code || '').toLowerCase().includes(query)
            );
            renderAgents(filtered);
        };

        document.getElementById('confirm-reassign-btn').onclick = async () => {
            const newAgentId = select.value;
            const { error: upError } = await supabase.from('client').update({ user_id: newAgentId }).eq('id', clientId);
            // Also transfer dues for this client
            await supabase.from('monthly_dues').update({ user_id: newAgentId }).eq('client_id', clientId);

            if (!upError) {
                alert("Client and their dues transferred successfully!");
                modal.classList.add('hidden');
                document.getElementById('client-detail-modal').classList.add('hidden');
                loadUsers();
            }
        };
    } catch(err) {
        console.error(err);
    }
};
