export const API = (
  import.meta.env.VITE_API_BASE_URL ||
  (import.meta.env.DEV
    ? "/api/v1"
    : "https://chessbraining-api.onrender.com/api/v1")
).replace(/\/$/, "");
export class ApiError extends Error {
  constructor(
    message: string,
    readonly status: number,
  ) {
    super(message);
  }
}
export async function request<T>(
  path: string,
  body?: unknown,
  method = body === undefined ? "GET" : "POST",
  signal?: AbortSignal,
): Promise<T> {
  const response = await fetch(API + path, {
    method,
    headers: { "Content-Type": "application/json" },
    body: body === undefined ? undefined : JSON.stringify(body),
    signal: signal ?? AbortSignal.timeout(75000),
  });
  const data = await response.json().catch(() => null);
  if (!response.ok)
    throw new ApiError(
      data?.message ||
        `Could not connect (${response.status}). Please try again.`,
      response.status,
    );
  return data as T;
}
export function socketUrl() {
  const url = new URL(API, location.origin);
  url.protocol = url.protocol === "https:" ? "wss:" : "ws:";
  url.pathname = "/ws";
  return url.href;
}
