const API_BASE = 'http://localhost:3000/api/v1/admin';

function getToken(): string | null {
	if (typeof window === 'undefined') return null;
	return localStorage.getItem('admin_token');
}

export function setToken(token: string) {
	localStorage.setItem('admin_token', token);
}

export function clearToken() {
	localStorage.removeItem('admin_token');
}

export function isAuthenticated(): boolean {
	return !!getToken();
}

async function request<T>(
	path: string,
	options: RequestInit = {}
): Promise<T> {
	const token = getToken();
	const headers: Record<string, string> = {
		'Content-Type': 'application/json',
		...(options.headers as Record<string, string>),
	};

	if (token) {
		headers['Authorization'] = `Bearer ${token}`;
	}

	const res = await fetch(`${API_BASE}${path}`, {
		...options,
		headers,
	});

	if (res.status === 401) {
		clearToken();
		if (typeof window !== 'undefined') {
			window.location.href = '/login';
		}
		throw new Error('Unauthorized');
	}

	const json = await res.json();

	if (!res.ok) {
		throw new Error(json.error || `Request failed: ${res.status}`);
	}

	return json;
}

function buildQuery(params: Record<string, any>): string {
	const searchParams = new URLSearchParams();
	for (const [key, value] of Object.entries(params)) {
		if (value !== undefined && value !== null && value !== '') {
			searchParams.set(key, String(value));
		}
	}
	const str = searchParams.toString();
	return str ? `?${str}` : '';
}

// ── Dashboard ───────────────────────────────────────────────────

export async function getDashboard() {
	return request<{ success: boolean; data: any }>('/dashboard');
}

// ── Transactions ────────────────────────────────────────────────

export async function getTransactions(filters: {
	userId?: string;
	groupId?: string;
	type?: string;
	dateFrom?: string;
	dateTo?: string;
	page?: number;
	limit?: number;
} = {}) {
	return request<{ success: boolean; data: { rows: any[]; total: number } }>(
		`/transactions${buildQuery(filters)}`
	);
}

// ── Activity Logs ───────────────────────────────────────────────

export async function getActivityLogs(filters: {
	userId?: string;
	action?: string;
	dateFrom?: string;
	dateTo?: string;
	page?: number;
	limit?: number;
} = {}) {
	return request<{ success: boolean; data: { rows: any[]; total: number } }>(
		`/activity-logs${buildQuery(filters)}`
	);
}

export async function purgeActivityLogs() {
	return request<{ success: boolean; message: string }>('/activity-logs/purge', {
		method: 'POST',
	});
}

export async function clearAllActivityLogs() {
	return request<{ success: boolean; message: string }>('/activity-logs/clear-all', {
		method: 'DELETE',
	});
}

export async function deleteActivityLog(id: string) {
	return request<{ success: boolean; message: string }>(`/activity-logs/${id}`, {
		method: 'DELETE',
	});
}

// ── Suspicious Logs ─────────────────────────────────────────────

export async function getSuspiciousLogs(filters: {
	userId?: string;
	type?: string;
	dateFrom?: string;
	dateTo?: string;
	page?: number;
	limit?: number;
} = {}) {
	return request<{ success: boolean; data: { rows: any[]; total: number } }>(
		`/suspicious-logs${buildQuery(filters)}`
	);
}

export async function flagSuspicious(data: {
	userId?: string;
	type: string;
	description: string;
	metadata?: any;
}) {
	return request<{ success: boolean; data: any }>('/suspicious-logs', {
		method: 'POST',
		body: JSON.stringify(data),
	});
}

export async function clearAllSuspiciousLogs() {
	return request<{ success: boolean; message: string }>('/suspicious-logs/clear-all', {
		method: 'DELETE',
	});
}

export async function deleteSuspiciousLog(id: string) {
	return request<{ success: boolean; message: string }>(`/suspicious-logs/${id}`, {
		method: 'DELETE',
	});
}

// ── Users ───────────────────────────────────────────────────────

export async function getUsers(filters: {
	search?: string;
	accountStatus?: string;
	role?: string;
	page?: number;
	limit?: number;
} = {}) {
	return request<{ success: boolean; data: { rows: any[]; total: number } }>(
		`/users${buildQuery(filters)}`
	);
}

export async function getUserDetail(id: string) {
	return request<{ success: boolean; data: any }>(`/users/${id}`);
}

export async function suspendUser(id: string, reason: string, durationDays?: number) {
	return request<{ success: boolean; data: any }>(`/users/${id}/suspend`, {
		method: 'PATCH',
		body: JSON.stringify({ reason, durationDays }),
	});
}

export async function banUser(id: string, reason: string) {
	return request<{ success: boolean; data: any }>(`/users/${id}/ban`, {
		method: 'PATCH',
		body: JSON.stringify({ reason }),
	});
}

export async function unsuspendUser(id: string, reason: string) {
	return request<{ success: boolean; data: any }>(`/users/${id}/unsuspend`, {
		method: 'PATCH',
		body: JSON.stringify({ reason }),
	});
}

// ── Disputes ────────────────────────────────────────────────────

export async function getDisputes(filters: {
	status?: string;
	dateFrom?: string;
	dateTo?: string;
	page?: number;
	limit?: number;
} = {}) {
	return request<{ success: boolean; data: { rows: any[]; total: number } }>(
		`/disputes${buildQuery(filters)}`
	);
}

export async function getDisputeDetail(id: string) {
	return request<{ success: boolean; data: any }>(`/disputes/${id}`);
}

export async function markDisputeUnderReview(id: string) {
	return request<{ success: boolean; data: any }>(`/disputes/${id}/review`, {
		method: 'PATCH',
	});
}

export async function resolveDispute(
	id: string,
	status: 'resolved_paid' | 'resolved_written_off' | 'resolved_rejected',
	note: string
) {
	return request<{ success: boolean; data: any }>(`/disputes/${id}/resolve`, {
		method: 'PATCH',
		body: JSON.stringify({ status, note }),
	});
}

// ── Audit Logs ──────────────────────────────────────────────────

export async function getAuditLogs(filters: {
	adminId?: string;
	page?: number;
	limit?: number;
} = {}) {
	return request<{ success: boolean; data: { rows: any[]; total: number } }>(
		`/audit-logs${buildQuery(filters)}`
	);
}

export async function clearAllAuditLogs() {
	return request<{ success: boolean; message: string }>('/audit-logs/clear-all', {
		method: 'DELETE',
	});
}

// ── Auth & LINE Login ───────────────────────────────────────────

const AUTH_BASE = 'http://localhost:3000/api/v1/auth';

export async function verifyLineToken(data: {
	idToken?: string;
	accessToken?: string;
	mockLineUserId?: string;
	mockDisplayName?: string;
}) {
	const res = await fetch(`${AUTH_BASE}/line/verify-token`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify(data),
	});

	const json = await res.json();
	if (!res.ok) {
		throw new Error(json.error || `LINE login failed: ${res.status}`);
	}

	if (json.user && json.user.role !== 'developer') {
		throw new Error('Access denied: User does not have developer/admin privileges');
	}

	if (json.accessToken) {
		setToken(json.accessToken);
	}

	return json;
}

export async function getMe() {
	const token = getToken();
	if (!token) return null;

	const res = await fetch(`${AUTH_BASE}/me`, {
		headers: {
			'Content-Type': 'application/json',
			Authorization: `Bearer ${token}`,
		},
	});

	if (!res.ok) {
		if (res.status === 401) {
			clearToken();
		}
		return null;
	}

	return res.json();
}

