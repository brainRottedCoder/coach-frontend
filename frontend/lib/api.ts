import type {
  JobStatusResponse,
  TypeCountResponse,
  UploadResponse,
} from "./types";

const API_URL =
  process.env.NEXT_PUBLIC_API_URL?.replace(/\/$/, "") || "http://localhost:8000";

async function parseError(res: Response): Promise<string> {
  try {
    const data = await res.json();
    if (typeof data?.detail === "string") return data.detail;
    if (Array.isArray(data?.detail)) {
      return data.detail.map((d: { msg?: string }) => d.msg || String(d)).join("; ");
    }
    return JSON.stringify(data);
  } catch {
    return res.statusText || `Request failed (${res.status})`;
  }
}

export async function uploadVideo(file: File): Promise<UploadResponse> {
  const form = new FormData();
  form.append("file", file);

  const res = await fetch(`${API_URL}/jobs/upload`, {
    method: "POST",
    body: form,
  });

  if (!res.ok) {
    throw new Error(await parseError(res));
  }

  return res.json();
}

export async function getJobStatus(jobId: string): Promise<JobStatusResponse> {
  const res = await fetch(`${API_URL}/jobs/${encodeURIComponent(jobId)}`, {
    cache: "no-store",
  });

  if (!res.ok) {
    throw new Error(await parseError(res));
  }

  return res.json();
}

export async function getTypeCount(jobId: string): Promise<TypeCountResponse> {
  const res = await fetch(
    `${API_URL}/jobs/${encodeURIComponent(jobId)}/type_count`,
    { cache: "no-store" },
  );

  if (!res.ok) {
    throw new Error(await parseError(res));
  }

  const data = await res.json();
  if (data.status && data.status !== "COMPLETED" && !("type_counts" in data)) {
    throw new Error(data.message || "Still processing");
  }

  return data as TypeCountResponse;
}

export async function pollUntilDone(
  jobId: string,
  onStatus?: (status: JobStatusResponse) => void,
  intervalMs = 2000,
  signal?: AbortSignal,
): Promise<JobStatusResponse> {
  while (true) {
    if (signal?.aborted) {
      throw new Error("Polling cancelled");
    }

    const status = await getJobStatus(jobId);
    onStatus?.(status);

    if (status.status === "COMPLETED") return status;
    if (status.status === "FAILED") {
      throw new Error(status.error_message || "Processing failed");
    }

    await new Promise<void>((resolve, reject) => {
      const timer = setTimeout(resolve, intervalMs);
      signal?.addEventListener(
        "abort",
        () => {
          clearTimeout(timer);
          reject(new Error("Polling cancelled"));
        },
        { once: true },
      );
    });
  }
}

export { API_URL };
