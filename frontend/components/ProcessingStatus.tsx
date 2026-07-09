"use client";

import { motion } from "framer-motion";
import type { JobStatus } from "@/lib/types";

type ProcessingStatusProps = {
  filename: string;
  status: JobStatus | "UPLOADING";
  jobId?: string | null;
};

const STATUS_COPY: Record<string, string> = {
  UPLOADING: "Sending footage to the platform…",
  PENDING: "Queued on the line — waiting for a clear path…",
  PROCESSING: "Scanning coaches and reading label plates…",
  COMPLETED: "Rake composition ready.",
  FAILED: "Signal failure — processing stopped.",
};

export function ProcessingStatus({
  filename,
  status,
  jobId,
}: ProcessingStatusProps) {
  return (
    <section className="relative py-20 md:py-28">
      <div className="mx-auto max-w-3xl px-6 text-center">
        <p className="mb-3 text-xs font-medium uppercase tracking-[0.3em] text-amber">
          Live on the line
        </p>
        <h2 className="font-display text-3xl tracking-wide text-mist md:text-4xl">
          Analysing passage
        </h2>
        <p className="mt-3 text-silver/80">{STATUS_COPY[status] || "Working…"}</p>
        <p className="mt-2 truncate text-sm text-rail">{filename}</p>
        {jobId && (
          <p className="mt-1 font-mono text-xs text-rail/70">{jobId}</p>
        )}

        {/* Track with moving train silhouette */}
        <div className="relative mx-auto mt-14 h-24 max-w-xl overflow-hidden">
          <div className="absolute inset-x-0 top-1/2 h-px -translate-y-1/2 bg-rail/40" />
          <div className="absolute inset-x-0 top-[calc(50%+8px)] h-px bg-rail/25" />
          <div className="absolute inset-x-0 top-[calc(50%-10px)] flex justify-between px-2">
            {Array.from({ length: 9 }).map((_, i) => (
              <span key={i} className="h-5 w-0.5 bg-rail/30" />
            ))}
          </div>

          <motion.div
            className="absolute top-1/2 flex -translate-y-[70%] items-end gap-0.5"
            animate={{ left: ["-20%", "110%"] }}
            transition={{ duration: 4.5, repeat: Infinity, ease: "linear" }}
          >
            <div className="h-7 w-10 rounded-sm bg-crimson" />
            <div className="h-6 w-8 rounded-sm bg-steel border border-rail/40" />
            <div className="h-6 w-8 rounded-sm bg-steel border border-rail/40" />
            <div className="h-6 w-8 rounded-sm bg-steel border border-rail/40" />
            <div className="h-6 w-8 rounded-sm bg-amber/80" />
          </motion.div>
        </div>

        <div className="mt-10 flex justify-center gap-2">
          {[0, 1, 2].map((i) => (
            <motion.span
              key={i}
              className="h-1.5 w-1.5 rounded-full bg-amber"
              animate={{ opacity: [0.2, 1, 0.2] }}
              transition={{ duration: 1.2, repeat: Infinity, delay: i * 0.25 }}
            />
          ))}
        </div>
      </div>
    </section>
  );
}
