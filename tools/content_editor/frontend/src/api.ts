import type { GameSchema } from "./types/schema.js";

const BASE = "/api";

async function apiFetch<T>(
  path: string,
  init?: RequestInit
): Promise<T> {
  const headers: Record<string, string> = init?.body != null
    ? { "Content-Type": "application/json" }
    : {};
  const res = await fetch(BASE + path, {
    headers,
    ...init,
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`${res.status} ${res.statusText}: ${body}`);
  }
  return res.json() as Promise<T>;
}

export const api = {
  schema: (): Promise<GameSchema> => apiFetch("/schema"),

  newResource: (path: string, cls: string): Promise<unknown> =>
    apiFetch(`/resource/new?path=${encodeURIComponent(path)}&class=${encodeURIComponent(cls)}`, {
      method: "POST",
    }),

  schemaRefresh: (): Promise<GameSchema> =>
    apiFetch("/schema/refresh", { method: "POST" }),

  listType: (cls: string): Promise<string[]> =>
    apiFetch(`/types/${encodeURIComponent(cls)}`),

  readResource: (path: string): Promise<unknown> =>
    apiFetch(`/resource?path=${encodeURIComponent(path)}`),

  writeResource: (path: string, data: unknown): Promise<{ ok: boolean }> =>
    apiFetch(`/resource?path=${encodeURIComponent(path)}`, {
      method: "POST",
      body: JSON.stringify(data),
    }),

  index: (): Promise<Record<string, { uid?: string; path: string; referenced_by: string[] }>> =>
    apiFetch("/index"),

  indexEntry: (
    uidOrPath: string
  ): Promise<{ uid?: string; path: string; referenced_by: string[] }> =>
    apiFetch(`/index/entry?uid=${encodeURIComponent(uidOrPath)}`),

  listAssets: (type: string): Promise<string[]> =>
    apiFetch(`/assets?type=${encodeURIComponent(type)}`),

  lint: (path: string): Promise<Array<{ path: string; message: string }>> =>
    apiFetch(`/lint?path=${encodeURIComponent(path)}`),

  lintData: (
    data: unknown
  ): Promise<Array<{ path: string; message: string }>> =>
    apiFetch("/lint", { method: "POST", body: JSON.stringify(data) }),

  listEvents: (dir: string): Promise<string[]> =>
    apiFetch(`/events?dir=${encodeURIComponent(dir)}`),

  readEvent: (path: string): Promise<unknown> =>
    apiFetch(`/event?path=${encodeURIComponent(path)}`),

  writeEvent: (path: string, data: unknown): Promise<{ ok: boolean }> =>
    apiFetch(`/event?path=${encodeURIComponent(path)}`, {
      method: "POST",
      body: JSON.stringify(data),
    }),

  resolvePath: (path: string): Promise<{ cls: string; path: string } | null> =>
    apiFetch<{ cls: string; path: string }>(`/resolve?path=${encodeURIComponent(path)}`).catch(() => null),

  listDialogues: (): Promise<string[]> =>
    apiFetch("/dialogues"),

  readDialogue: (path: string): Promise<unknown> =>
    apiFetch(`/dialogue?path=${encodeURIComponent(path)}`),

  writeDialogue: (path: string, data: unknown): Promise<{ ok: boolean }> =>
    apiFetch(`/dialogue?path=${encodeURIComponent(path)}`, {
      method: "POST",
      body: JSON.stringify(data),
    }),
};
