"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { motion } from "framer-motion";
import { ALLOWED_EXTENSIONS, isAllowedVideo } from "@/lib/coachMeta";

type UploadZoneProps = {
  file: File | null;
  onFileSelect: (file: File | null) => void;
  onAnalyze: () => void;
  disabled?: boolean;
};

export function UploadZone({
  file,
  onFileSelect,
  onAnalyze,
  disabled,
}: UploadZoneProps) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [dragging, setDragging] = useState(false);
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [localError, setLocalError] = useState<string | null>(null);

  useEffect(() => {
    if (!file) {
      setPreviewUrl(null);
      return;
    }
    const url = URL.createObjectURL(file);
    setPreviewUrl(url);
    return () => URL.revokeObjectURL(url);
  }, [file]);

  const acceptFile = useCallback(
    (next: File | undefined | null) => {
      if (!next) return;
      if (!isAllowedVideo(next)) {
        setLocalError(`Unsupported format. Use ${ALLOWED_EXTENSIONS.join(", ")}`);
        return;
      }
      setLocalError(null);
      onFileSelect(next);
    },
    [onFileSelect],
  );

  return (
    <section id="upload" className="relative scroll-mt-20 py-16 md:py-24">
      <div className="mx-auto max-w-5xl px-6">
        <p className="mb-2 text-xs font-medium uppercase tracking-[0.3em] text-amber">
          Platform intake
        </p>
        <h2 className="font-display text-3xl tracking-wide text-mist md:text-4xl">
          Drop your train video
        </h2>
        <p className="mt-2 max-w-lg text-silver/80">
          Side-view station footage works best. We detect coaches, count the rake,
          and classify types from label plates.
        </p>

        <motion.div
          layout
          onDragOver={(e) => {
            e.preventDefault();
            setDragging(true);
          }}
          onDragLeave={() => setDragging(false)}
          onDrop={(e) => {
            e.preventDefault();
            setDragging(false);
            acceptFile(e.dataTransfer.files?.[0]);
          }}
          className={`station-glow mt-10 overflow-hidden bg-steel/60 transition ${
            dragging ? "ring-2 ring-amber" : ""
          }`}
        >
          <div
            className="flex min-h-[220px] cursor-pointer flex-col items-center justify-center gap-3 border border-dashed border-rail/30 px-6 py-12 text-center transition hover:border-amber/50"
            onClick={() => !disabled && inputRef.current?.click()}
            onKeyDown={(e) => {
              if (e.key === "Enter" || e.key === " ") inputRef.current?.click();
            }}
            role="button"
            tabIndex={0}
          >
            <div className="flex h-14 w-14 items-center justify-center border border-rail/40 text-amber">
              <svg width="28" height="28" viewBox="0 0 24 24" fill="none" aria-hidden>
                <path
                  d="M12 4v10m0-10l-4 4m4-4l4 4M4 16v2a2 2 0 002 2h12a2 2 0 002-2v-2"
                  stroke="currentColor"
                  strokeWidth="1.5"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                />
              </svg>
            </div>
            <p className="text-mist">
              {dragging ? "Release to load" : "Drag & drop or click to browse"}
            </p>
            <p className="text-sm text-rail">
              {ALLOWED_EXTENSIONS.join(" · ").toUpperCase()}
            </p>
            <input
              ref={inputRef}
              type="file"
              accept={ALLOWED_EXTENSIONS.join(",")}
              className="hidden"
              disabled={disabled}
              onChange={(e) => acceptFile(e.target.files?.[0])}
            />
          </div>

          {previewUrl && file && (
            <div className="border-t border-rail/20 bg-navy/50 p-4 md:p-6">
              <div className="grid gap-6 md:grid-cols-[1.2fr_0.8fr] md:items-end">
                <video
                  src={previewUrl}
                  controls
                  className="aspect-video w-full bg-black object-contain"
                />
                <div className="space-y-4">
                  <div>
                    <p className="text-xs uppercase tracking-widest text-rail">Selected</p>
                    <p className="mt-1 break-all font-medium text-mist">{file.name}</p>
                    <p className="mt-1 text-sm text-silver/70">
                      {(file.size / (1024 * 1024)).toFixed(1)} MB
                    </p>
                  </div>
                  <div className="flex flex-wrap gap-3">
                    <button
                      type="button"
                      disabled={disabled}
                      onClick={onAnalyze}
                      className="bg-amber px-6 py-3 text-sm font-semibold uppercase tracking-widest text-navy transition hover:brightness-110 disabled:opacity-50"
                    >
                      Analyse rake
                    </button>
                    <button
                      type="button"
                      disabled={disabled}
                      onClick={() => {
                        onFileSelect(null);
                        setLocalError(null);
                        if (inputRef.current) inputRef.current.value = "";
                      }}
                      className="border border-rail/40 px-5 py-3 text-sm uppercase tracking-widest text-silver transition hover:border-silver disabled:opacity-50"
                    >
                      Clear
                    </button>
                  </div>
                </div>
              </div>
            </div>
          )}
        </motion.div>

        {localError && (
          <p className="mt-4 text-sm text-crimson" role="alert">
            {localError}
          </p>
        )}
      </div>
    </section>
  );
}
