// ── DAB Data Layer ──
// Depends on: config.js (CONFIG)
// Pure data — no DOM, no rendering.

const API_URL = window.location.hostname === 'localhost' ? CONFIG.apiUrlLocal : CONFIG.apiUrlAzure;

async function fetchTodos() {
    try {
        const res = await fetch(`${API_URL}/api/Todos`);
        if (!res.ok) throw new Error(res.status);
        const data = await res.json();
        return data.value || [];
    } catch (e) {
        console.error('Fetch failed:', e.message);
        return [];
    }
}

async function createTodo(title, dueDate) {
    const headers = { 'Content-Type': 'application/json' };
    const body = JSON.stringify({
        Title: title,
        DueDate: dueDate,
        Owner: 'anonymous',
        Completed: false
    });
    const res = await fetch(`${API_URL}/api/Todos`, { method: 'POST', headers, body });
    if (!res.ok) { console.error('Create failed:', res.status); return false; }
    return true;
}

async function toggleTodo(id, completed) {
    const headers = { 'Content-Type': 'application/json' };
    const res = await fetch(`${API_URL}/api/Todos/TodoId/${id}`, {
        method: 'PATCH', headers,
        body: JSON.stringify({ Completed: !completed })
    });
    if (!res.ok) { console.error('Update failed:', res.status); return false; }
    return true;
}

async function deleteTodo(id) {
    const res = await fetch(`${API_URL}/api/Todos/TodoId/${id}`, { method: 'DELETE' });
    if (!res.ok) { console.error('Delete failed:', res.status); return false; }
    return true;
}
