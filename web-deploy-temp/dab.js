// ── DAB Data Layer ──
// Depends on: config.js (CONFIG), auth.js (getAuthHeaders, currentAccount)
// Pure data — no DOM, no rendering.

const API_URL = window.location.hostname === 'localhost' ? CONFIG.apiUrlLocal : CONFIG.apiUrlAzure;

async function fetchTodos() {
    if (!currentAccount) return [];
    try {
        const headers = await getAuthHeaders();
        const res = await fetch(`${API_URL}/api/Todos`, { headers });
        if (!res.ok) throw new Error(res.status);
        const data = await res.json();
        return data.value || [];
    } catch (e) {
        console.error('Fetch failed:', e.message);
        return [];
    }
}

async function createTodo(title, dueDate) {
    const headers = { ...await getAuthHeaders(), 'Content-Type': 'application/json' };
    const body = JSON.stringify({
        Title: title,
        DueDate: dueDate,
        Owner: currentAccount.username,
        Completed: false
    });
    const res = await fetch(`${API_URL}/api/Todos`, { method: 'POST', headers, body });
    if (!res.ok) { console.error('Create failed:', res.status); return false; }
    return true;
}

async function toggleTodo(id, completed) {
    const headers = { ...await getAuthHeaders(), 'Content-Type': 'application/json' };
    const res = await fetch(`${API_URL}/api/Todos/TodoId/${id}`, {
        method: 'PATCH', headers,
        body: JSON.stringify({ Completed: !completed })
    });
    if (!res.ok) { console.error('Update failed:', res.status); return false; }
    return true;
}

async function deleteTodo(id) {
    const headers = await getAuthHeaders();
    const res = await fetch(`${API_URL}/api/Todos/TodoId/${id}`, { method: 'DELETE', headers });
    if (!res.ok) { console.error('Delete failed:', res.status); return false; }
    return true;
}
