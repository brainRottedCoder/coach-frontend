"use client";

import { useCallback, useRef, useState } from "react";
import { getTypeCount, pollUntilDone, uploadVideo } from "@/lib/api";
import type { AppPhase, JobStatus, TypeCountResponse } from "@/lib/types";
import { Hero } from "@/components/Hero";
import { UploadZone } from "@/components/UploadZone";
import { ProcessingStatus } from "@/components/ProcessingStatus";
import { ResultsPanel } from "@/components/ResultsPanel";

export default function HomePage() {
  const [file, setFile] = useState<File | null>(null);
  const [phase, setPhase] = useState<AppPhase>("idle");
  const [jobId, setJobId] = useState<string | null>(null);
  const [jobStatus, setJobStatus] = useState<JobStatus | "UPLOADING">("PENDING");
  const [result, setResult] = useState<TypeCountResponse | null>(null);
  const [error, setError] = useState<string | null>(null);
  const abortRef = useRef<AbortController | null>(null);

  const scrollTo = (id: string) => {
    document.getElementById(id)?.scrollIntoView({ behavior: "smooth" });
  };

  const reset = useCallback(() => {
    abortRef.current?.abort();
    abortRef.current = null;
    setFile(null);
    setPhase("idle");
    setJobId(null);
    setJobStatus("PENDING");
    setResult(null);
    setError(null);
    window.scrollTo({ top: 0, behavior: "smooth" });
  }, []);

  const handleAnalyze = useCallback(async () => {
    if (!file) return;

    abortRef.current?.abort();
    const controller = new AbortController();
    abortRef.current = controller;

    setError(null);
    setResult(null);
    setPhase("uploading");
    setJobStatus("UPLOADING");

    try {
      const uploaded = await uploadVideo(file);
      if (controller.signal.aborted) return;

      setJobId(uploaded.job_id);
      setPhase("processing");
      setJobStatus("PENDING");

      const finalStatus = await pollUntilDone(
        uploaded.job_id,
        (s) => setJobStatus(s.status),
        2000,
        controller.signal,
      );

      const typeResult = await getTypeCount(finalStatus.job_id);
      if (controller.signal.aborted) return;

      setResult(typeResult);
      setPhase("results");
      setTimeout(() => scrollTo("results"), 100);
    } catch (err) {
      if (controller.signal.aborted) return;
      const message = err instanceof Error ? err.message : "Something went wrong";
      setError(message);
      setPhase("error");
    }
  }, [file]);

  const busy = phase === "uploading" || phase === "processing";

  return (
    <main className="rail-atmosphere relative min-h-screen">
      <header className="fixed left-0 right-0 top-0 z-50 border-b border-white/5 bg-navy/70 backdrop-blur-md">
        <div className="mx-auto flex max-w-5xl items-center justify-between px-6 py-3">
          <button
            type="button"
            onClick={reset}
            className="font-display text-lg tracking-[0.2em] text-mist"
          >
            ATCR
          </button>
          <button
            type="button"
            onClick={() => scrollTo("upload")}
            className="text-xs uppercase tracking-widest text-rail transition hover:text-amber"
          >
            Upload
          </button>
        </div>
      </header>

      {phase !== "processing" && phase !== "uploading" && phase !== "results" && (
        <Hero onUploadClick={() => scrollTo("upload")} />
      )}

      {(phase === "idle" || phase === "ready" || phase === "error" || (!busy && phase !== "results")) && (
        <UploadZone
          file={file}
          onFileSelect={(f) => {
            setFile(f);
            setPhase(f ? "ready" : "idle");
            setError(null);
          }}
          onAnalyze={handleAnalyze}
          disabled={busy}
        />
      )}

      {(phase === "uploading" || phase === "processing") && (
        <ProcessingStatus
          filename={file?.name || "video"}
          status={jobStatus}
          jobId={jobId}
        />
      )}

      {phase === "error" && error && (
        <div className="mx-auto max-w-5xl px-6 pb-12">
          <div
            className="border border-crimson/40 bg-crimson/10 px-5 py-4 text-sm text-mist"
            role="alert"
          >
            <p className="font-semibold text-crimson">Signal failure</p>
            <p className="mt-1 text-silver/90">{error}</p>
            <p className="mt-2 text-xs text-rail">
              Ensure the API is running at{" "}
              <code className="text-amber">
                {process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000"}
              </code>
            </p>
          </div>
        </div>
      )}

      {phase === "results" && result && (
        <ResultsPanel
          result={result}
          filename={file?.name || result.job_id}
          onReset={reset}
        />
      )}

      <footer className="border-t border-white/5 py-8 text-center text-xs text-rail">
        Automatic Train Composition Recognition · Coach Detection
      </footer>
    </main>
  );
}
