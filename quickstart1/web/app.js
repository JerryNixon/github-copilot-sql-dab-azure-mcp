// ── App UI Layer ──
// Depends on: dab.js (fetchTodos, createTodo, toggleTodo, deleteTodo)

let tasks = [];

// ── Rendering ──

function renderTasks() {
    const list = document.getElementById('tasksList');

    if (tasks.length === 0) {
        list.innerHTML = `
            <div class="empty-state">
                <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                          d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                </svg>
                <p>No tasks yet — add one above</p>
            </div>`;
        return;
    }

    list.innerHTML = tasks.map(t => `
        <div class="task-item">
            <button class="task-check ${t.Completed ? 'completed' : ''}" data-id="${t.TodoId}" data-completed="${t.Completed}" data-action="toggle">
                ${t.Completed ? '✓' : ''}
            </button>
            <div class="task-content">
                <div class="task-title ${t.Completed ? 'completed' : ''}">${escapeHtml(t.Title)}</div>
                <div class="task-meta">Due ${new Date(t.DueDate).toLocaleDateString()}</div>
            </div>
            <button class="task-delete" data-id="${t.TodoId}" data-action="delete">✕</button>
        </div>
    `).join('');
}

function escapeHtml(str) {
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
}

// ── Actions (bridge UI → data) ──

async function loadTodos() {
    tasks = await fetchTodos();
    renderTasks();
}

async function handleCreate(title, dueDate) {
    if (await createTodo(title, dueDate)) await loadTodos();
}

async function handleToggle(id, completed) {
    if (await toggleTodo(id, completed)) await loadTodos();
}

async function handleDelete(id) {
    if (await deleteTodo(id)) await loadTodos();
}

// ── Init ──

loadTodos();

// ── Event listeners ──

document.getElementById('refreshBtn').addEventListener('click', loadTodos);

document.getElementById('addForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    const titleInput = document.getElementById('newTitle');
    const dateInput = document.getElementById('newDueDate');
    const title = titleInput.value.trim();
    const dueDate = dateInput.value;
    if (!title || !dueDate) return;
    titleInput.value = '';
    dateInput.value = new Date().toISOString().split('T')[0];
    await handleCreate(title, dueDate);
});

// Event delegation for task buttons
document.getElementById('tasksList').addEventListener('click', async (e) => {
    const btn = e.target.closest('[data-action]');
    if (!btn) return;
    const id = Number(btn.dataset.id);
    if (btn.dataset.action === 'toggle') {
        await handleToggle(id, btn.dataset.completed === 'true');
    } else if (btn.dataset.action === 'delete') {
        await handleDelete(id);
    }
});

// Set default date to today
document.getElementById('newDueDate').value = new Date().toISOString().split('T')[0];
