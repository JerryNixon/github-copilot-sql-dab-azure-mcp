// MSAL Configuration
const msalConfig = {
    auth: {
        clientId: CONFIG.clientId,
        authority: `https://login.microsoftonline.com/${CONFIG.tenantId}`,
        redirectUri: window.location.origin
    },
    cache: {
        cacheLocation: 'localStorage',
        storeAuthStateInCookie: false
    }
};

const msalInstance = new msal.PublicClientApplication(msalConfig);
const loginRequest = {
    scopes: ['User.Read', `api://${CONFIG.clientId}/access_as_user`]
};

const tokenRequest = {
    scopes: [`api://${CONFIG.clientId}/access_as_user`]
};

const API_URL = window.location.hostname === 'localhost'
    ? CONFIG.apiUrlLocal
    : CONFIG.apiUrlAzure;
let currentAccount = null;
let tasks = [];

async function fetchTodos() {
    try {
        console.log(`Fetching todos from ${API_URL}/api/Todos`);
        const headers = {};
        if (currentAccount) {
            try {
                const tokenResponse = await msalInstance.acquireTokenSilent({
                    ...tokenRequest,
                    account: currentAccount
                });
                headers['Authorization'] = `Bearer ${tokenResponse.accessToken}`;
            } catch (e) {
                console.warn('Silent token acquisition failed, trying redirect:', e);
                await msalInstance.acquireTokenRedirect(tokenRequest);
                return;
            }
        }
        const response = await fetch(`${API_URL}/api/Todos`, { headers });
        
        if (!response.ok) {
            console.error('API error response:', {
                status: response.status,
                statusText: response.statusText,
                url: response.url,
                headers: Object.fromEntries(response.headers.entries())
            });
            const body = await response.text().catch(() => '(unreadable)');
            console.error('API error body:', body);
            throw new Error(`API returned ${response.status} ${response.statusText}`);
        }
        
        const data = await response.json();
        console.log(`Fetched ${(data.value || []).length} todos`);
        
        // DAB returns data in { value: [...] } format
        tasks = data.value || [];
        renderTasks();
    } catch (error) {
        console.error('Failed to fetch todos:', {
            message: error.message,
            name: error.name,
            stack: error.stack,
            apiUrl: API_URL
        });
        tasks = [];
        renderTasks();
    }
}

function renderTasks() {
    const container = document.getElementById('tasksList');
    
    if (tasks.length === 0) {
        container.innerHTML = `
            <div class="empty-state">
                <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                          d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                </svg>
                <p>No tasks yet</p>
            </div>
        `;
        return;
    }

    container.innerHTML = tasks.map(task => `
        <div class="task-item">
            <div class="task-status ${task.Completed ? 'completed' : ''}"></div>
            <div class="task-content">
                <div class="task-title ${task.Completed ? 'completed' : ''}">${task.Title}</div>
                <div class="task-meta">Due ${new Date(task.DueDate).toLocaleDateString()}</div>
            </div>
            <div class="task-owner">${task.Owner}</div>
        </div>
    `).join('');
}

async function handleLogin() {
    try {
        console.log('Starting login redirect...', { clientId: CONFIG.clientId, tenantId: CONFIG.tenantId });
        await msalInstance.loginRedirect(loginRequest);
    } catch (error) {
        console.error('Login failed:', {
            message: error.message,
            errorCode: error.errorCode,
            errorMessage: error.errorMessage,
            subError: error.subError,
            stack: error.stack
        });
    }
}

async function handleLogout() {
    try {
        console.log('Starting logout...', { account: currentAccount?.username });
        await msalInstance.logoutRedirect({
            account: currentAccount
        });
    } catch (error) {
        console.error('Logout failed:', {
            message: error.message,
            errorCode: error.errorCode,
            stack: error.stack
        });
    }
}

function updateUI() {
    const loginBtn = document.getElementById('loginBtn');
    const userInfo = document.getElementById('userInfo');

    if (currentAccount) {
        userInfo.textContent = currentAccount.name || currentAccount.username;
        loginBtn.textContent = 'Sign Out';
        loginBtn.onclick = handleLogout;
    } else {
        userInfo.textContent = 'Not signed in';
        loginBtn.textContent = 'Sign In';
        loginBtn.onclick = handleLogin;
    }
}

// Initialize on page load
async function initializeApp() {
    try {
        console.log('Initializing MSAL...');
        await msalInstance.initialize();
        
        // Handle redirect response (returns after Microsoft login)
        console.log('Handling redirect...');
        const response = await msalInstance.handleRedirectPromise();
        
        if (response) {
            console.log('Login successful:', response.account);
            currentAccount = response.account;
        } else {
            console.log('No redirect response, checking for existing session...');
            // Check if already logged in
            const accounts = msalInstance.getAllAccounts();
            console.log('Found accounts:', accounts.length);
            if (accounts.length > 0) {
                currentAccount = accounts[0];
                console.log('Using existing account:', currentAccount);
            }
        }
        
        updateUI();
        await fetchTodos();
    } catch (error) {
        console.error('Initialization error:', {
            message: error.message,
            errorCode: error.errorCode,
            errorMessage: error.errorMessage,
            subError: error.subError,
            correlationId: error.correlationId,
            stack: error.stack
        });
    }
}

initializeApp();

// Refresh button handler
document.getElementById('refreshBtn').addEventListener('click', async () => {
    console.log('Refresh clicked');
    await fetchTodos();
});
