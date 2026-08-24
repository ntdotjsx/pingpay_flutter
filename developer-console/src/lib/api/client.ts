export const BASE_URL = import.meta.env.VITE_API_URL || 'https://pingpay-api.fly.dev';
export const API_BASE = `${BASE_URL}/api/v1/admin`;
export const AUTH_BASE = `${BASE_URL}/api/v1/auth`;


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

export async function getAnalytics() {
	return request<{ success: boolean; data: any }>('/analytics');
}

// ── Transactions ────────────────────────────────────────────────

export async function getTransactions(filters: {
	userId?: string;
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

// ── Rewards Catalog & Redemptions ───────────────────────────────

export async function getRewardItems() {
	return request<{ success: boolean; data: { items: any[] } }>('/rewards/items');
}

export async function createRewardItem(data: {
	title: string;
	description?: string;
	pointsCost: number;
	category?: string;
	imageUrl?: string;
	inStock: number;
	isActive?: boolean;
}) {
	return request<{ success: boolean; data: any }>('/rewards/items', {
		method: 'POST',
		body: JSON.stringify(data),
	});
}

export async function updateRewardItem(
	id: string,
	data: Partial<{
		title: string;
		description: string;
		pointsCost: number;
		category: string;
		imageUrl: string;
		inStock: number;
		isActive: boolean;
	}>
) {
	return request<{ success: boolean; data: any }>(`/rewards/items/${id}`, {
		method: 'PATCH',
		body: JSON.stringify(data),
	});
}

export async function deleteRewardItem(id: string) {
	return request<{ success: boolean; message: string }>(`/rewards/items/${id}`, {
		method: 'DELETE',
	});
}

export async function getRewardRedemptions(filters: {
	status?: string;
	page?: number;
	limit?: number;
} = {}) {
	return request<{ success: boolean; data: { rows: any[]; total: number } }>(
		`/rewards/redemptions${buildQuery(filters)}`
	);
}

export async function updateRedemptionStatus(
	id: string,
	status: 'pending_delivery' | 'shipped' | 'delivered' | 'cancelled',
	trackingNumber?: string
) {
	return request<{ success: boolean; data: any }>(`/rewards/redemptions/${id}/status`, {
		method: 'PATCH',
		body: JSON.stringify({ status, trackingNumber }),
	});
}

// ── Notification Outbox ─────────────────────────────────────────

export async function getNotificationOutbox(filters: {
	status?: string;
	eventType?: string;
	page?: number;
	limit?: number;
} = {}) {
	return request<{ success: boolean; data: { rows: any[]; total: number } }>(
		`/notifications/outbox${buildQuery(filters)}`
	);
}

export async function retryNotification(id: string) {
	return request<{ success: boolean; data: any }>(`/notifications/outbox/${id}/retry`, {
		method: 'POST',
	});
}

export async function sendFcmNotification(data: {
	target: 'all' | 'user' | 'token';
	userId?: string;
	deviceToken?: string;
	title: string;
	body: string;
	imageUrl?: string;
	dataPayload?: any;
}) {
	return request<{
		success: boolean;
		message: string;
		data: { sentCount: number; failedCount: number; errors: string[] };
	}>('/notifications/send-fcm', {
		method: 'POST',
		body: JSON.stringify(data),
	});
}

export async function getFcmUsers(search?: string) {
	const query = search ? `?search=${encodeURIComponent(search)}` : '';
	return request<{
		success: boolean;
		data: { users: any[] };
	}>(`/notifications/fcm-users${query}`);
}

// ── Security Events ─────────────────────────────────────────────

export async function getSecurityEvents(filters: {
	userId?: string;
	event?: string;
	page?: number;
	limit?: number;
} = {}) {
	return request<{ success: boolean; data: { rows: any[]; total: number } }>(
		`/security-events${buildQuery(filters)}`
	);
}

// ── Bills ───────────────────────────────────────────────────────

export async function getBills(filters: {
	ownerId?: string;
	status?: string;
	search?: string;
	dateFrom?: string;
	dateTo?: string;
	page?: number;
	limit?: number;
} = {}) {
	return request<{ success: boolean; data: { rows: any[]; total: number } }>(
		`/bills${buildQuery(filters)}`
	);
}

export async function getBillDetail(id: string) {
	return request<{ success: boolean; data: any }>(`/bills/${id}`);
}

// ── Payments ────────────────────────────────────────────────────

export async function getPayments(filters: {
	payerId?: string;
	status?: string;
	channel?: string;
	method?: string;
	dateFrom?: string;
	dateTo?: string;
	page?: number;
	limit?: number;
} = {}) {
	return request<{ success: boolean; data: { rows: any[]; total: number } }>(
		`/payments${buildQuery(filters)}`
	);
}

export async function getPaymentDetail(id: string) {
	return request<{ success: boolean; data: any }>(`/payments/${id}`);
}

// ── Maintenance & Live DB Stats ─────────────────────────────────

export async function getDbStats() {
	return request<{
		success: boolean;
		data: {
			users: number;
			bills: number;
			billItems: number;
			payments: number;
			paymentVerifications: number;
			financialTransactions: number;
			disputes: number;
			friendships: number;
			editLogs: number;
			activityLogs: number;
			suspiciousActivityLogs: number;
			adminActionLogs: number;
			notificationOutbox: number;
			notificationDeliveries: number;
			deviceTokens: number;
			securityEvents: number;
			rewardItems: number;
			rewardRedemptions: number;
			consentRecords: number;
			authIdentities: number;
			authSessions: number;
		};
	}>('/maintenance/db-stats');
}

// ── Auth & Google Login ─────────────────────────────────────────

export async function verifyGoogleToken(data: {
	idToken?: string;
	accessToken?: string;
	mockGoogleId?: string;
	mockDisplayName?: string;
	mockEmail?: string;
}) {
	const res = await fetch(`${AUTH_BASE}/google/verify-token`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json' },
		body: JSON.stringify(data),
	});

	const json = await res.json();
	if (!res.ok) {
		throw new Error(json.error || `Google login failed: ${res.status}`);
	}

	if (json.user && json.user.role !== 'developer') {
		throw new Error('Access denied: User does not have developer/admin privileges');
	}

	if (json.accessToken) {
		setToken(json.accessToken);
	}

	return json;
}

// Alias for backwards compatibility
export const verifyLineToken = verifyGoogleToken;

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

