// MSAL Configuration
const msalConfig = {
    auth: {
        clientId: CONFIG.clientId,
        authority: `https://login.microsoftonline.com/${CONFIG.tenantId}`,
        redirectUri: window.location.origin
    },
    cache: { cacheLocation: 'localStorage', storeAuthStateInCookie: false }
};

const msalInstance = new msal.PublicClientApplication(msalConfig);
const loginRequest = { scopes: ['User.Read', `api://${CONFIG.clientId}/access_as_user`] };
const tokenRequest = { scopes: [`api://${CONFIG.clientId}/access_as_user`] };

let currentAccount = null;

async function getAuthHeaders() {
    if (!currentAccount) return {};
    try {
        const r = await msalInstance.acquireTokenSilent({ ...tokenRequest, account: currentAccount });
        return { 'Authorization': `Bearer ${r.accessToken}` };
    } catch {
        await msalInstance.acquireTokenRedirect(tokenRequest);
        return {};
    }
}

async function handleLogin() {
    await msalInstance.loginRedirect(loginRequest);
}

async function initAuth() {
    await msalInstance.initialize();
    const response = await msalInstance.handleRedirectPromise();
    if (response) {
        currentAccount = response.account;
    } else {
        const accounts = msalInstance.getAllAccounts();
        if (accounts.length > 0) {
            currentAccount = accounts[0];
        } else {
            // Auto-redirect: no manual login button needed
            await handleLogin();
            return;
        }
    }
}
