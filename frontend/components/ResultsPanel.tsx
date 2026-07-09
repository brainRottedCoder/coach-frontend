"use client";

import { motion } from "framer-motion";
import type { TypeCountResponse } from "@/lib/types";
import {
  COACH_TYPE_ORDER,
  coachColor,
  coachLabel,
} from "@/lib/coachMeta";
import { CoachStrip } from "./CoachStrip";

type ResultsPanelProps = {
  result: TypeCountResponse;
  filename: string;
  onReset: () => void;
};

function orderedTypeEntries(typeCounts: Record<string, number>) {
  const known = COACH_TYPE_ORDER.filter((k) => (typeCounts[k] ?? 0) > 0).map(
    (k) => [k, typeCounts[k]] as const,
  );
  const extras = Object.entries(typeCounts).filter(
    ([k, v]) => v > 0 && !COACH_TYPE_ORDER.includes(k as (typeof COACH_TYPE_ORDER)[number]),
  );
  return [...known, ...extras];
}

export function ResultsPanel({ result, filename, onReset }: ResultsPanelProps) {
  const types = orderedTypeEntries(result.type_counts);
  const maxType = Math.max(...types.map(([, n]) => n), 1);
  const coveragePct = Math.round((result.composition_coverage || 0) * 100);

  return (
    <section id="results" className="relative scroll-mt-16 pb-24 pt-8 md:pt-12">
      <div className="mx-auto max-w-5xl px-6">
        <div className="flex flex-wrap items-end justify-between gap-4">
          <div>
            <p className="mb-2 text-xs font-medium uppercase tracking-[0.3em] text-amber">
              Passage report
            </p>
            <h2 className="font-display text-3xl tracking-wide text-mist md:text-4xl">
              Rake composition
            </h2>
            <p className="mt-2 truncate text-sm text-rail">{filename}</p>
          </div>
          <button
            type="button"
            onClick={onReset}
            className="border border-rail/40 px-5 py-2.5 text-xs uppercase tracking-widest text-silver transition hover:border-amber hover:text-amber"
          >
            Analyse another
          </button>
        </div>

        {/* Hero metric */}
        <motion.div
          initial={{ opacity: 0, scale: 0.96 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ duration: 0.5 }}
          className="station-glow mt-10 grid gap-6 bg-steel/50 p-8 md:grid-cols-[1fr_auto] md:items-center"
        >
          <div>
            <p className="text-xs uppercase tracking-[0.25em] text-rail">Total coaches</p>
            <p className="font-display mt-2 text-[clamp(4rem,12vw,7rem)] leading-none text-mist">
              {result.total_coaches}
            </p>
            <p className="mt-3 text-sm text-silver/75">
              {result.composition_known_count} typed · {coveragePct}% composition coverage
              {result.counts_match_total ? " · counts reconciled" : ""}
            </p>
          </div>
          <div className="grid grid-cols-3 gap-4 text-center md:min-w-[240px]">
            <Stat label="Labels" value={result.label_track_count} />
            <Stat label="Bodies" value={result.coach_track_count} />
            <Stat label="Fallback" value={result.fallback_count} />
          </div>
        </motion.div>

        {/* Type breakdown */}
        <div className="mt-12">
          <h3 className="font-display text-xl tracking-wide text-mist">Type breakdown</h3>
          <div className="mt-6 space-y-4">
            {types.length === 0 && (
              <p className="text-sm text-rail">No type counts returned.</p>
            )}
            {types.map(([type, count], i) => (
              <motion.div
                key={type}
                initial={{ opacity: 0, x: -12 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: 0.05 * i }}
                className="grid grid-cols-[7rem_1fr_2.5rem] items-center gap-3 md:grid-cols-[9rem_1fr_3rem]"
              >
                <span className="text-sm text-silver">{coachLabel(type)}</span>
                <div className="h-2.5 overflow-hidden bg-navy">
                  <motion.div
                    className="h-full"
                    style={{ backgroundColor: coachColor(type) }}
                    initial={{ width: 0 }}
                    animate={{ width: `${(count / maxType) * 100}%` }}
                    transition={{ duration: 0.7, delay: 0.1 + i * 0.05 }}
                  />
                </div>
                <span className="text-right font-mono text-sm text-mist">{count}</span>
              </motion.div>
            ))}
          </div>

          <div className="mt-6 flex flex-wrap gap-2">
            {types.map(([type]) => (
              <span
                key={`chip-${type}`}
                className="inline-flex items-center gap-2 border border-white/10 px-3 py-1 text-xs text-silver"
              >
                <span
                  className="h-2 w-2 rounded-full"
                  style={{ backgroundColor: coachColor(type) }}
                />
                {coachLabel(type)}
              </span>
            ))}
          </div>
        </div>

        {/* Coach strip */}
        <div className="mt-14">
          <h3 className="font-display text-xl tracking-wide text-mist">
            Ordered rake
          </h3>
          <p className="mt-1 text-sm text-rail">
            Left → right follows passage order. Amber dots mark inferred slots.
          </p>
          <div className="station-glow mt-5 bg-navy-mid/80 p-4 md:p-6">
            <CoachStrip composition={result.composition || []} />
          </div>
        </div>

        {/* Label reads */}
        <div className="mt-14">
          <h3 className="font-display text-xl tracking-wide text-mist">
            Label plate reads
          </h3>
          <div className="station-glow mt-5 overflow-x-auto bg-steel/40">
            <table className="w-full min-w-[640px] text-left text-sm">
              <thead>
                <tr className="border-b border-rail/20 text-xs uppercase tracking-wider text-rail">
                  <th className="px-4 py-3 font-medium">Track</th>
                  <th className="px-4 py-3 font-medium">Raw OCR</th>
                  <th className="px-4 py-3 font-medium">Type</th>
                  <th className="px-4 py-3 font-medium">Code</th>
                  <th className="px-4 py-3 font-medium">Conf.</th>
                </tr>
              </thead>
              <tbody>
                {(result.label_reads || []).length === 0 && (
                  <tr>
                    <td colSpan={5} className="px-4 py-8 text-center text-rail">
                      No OCR label reads for this job.
                    </td>
                  </tr>
                )}
                {(result.label_reads || []).map((read) => (
                  <tr
                    key={`${read.track_id}-${read.frame_index ?? 0}-${read.raw_text}`}
                    className="border-b border-rail/10 text-silver/90 last:border-0"
                  >
                    <td className="px-4 py-3 font-mono text-mist">{read.track_id}</td>
                    <td className="px-4 py-3 font-mono text-xs">
                      {read.raw_text || "—"}
                    </td>
                    <td className="px-4 py-3">
                      <span className="inline-flex items-center gap-2">
                        <span
                          className="h-2 w-2 rounded-full"
                          style={{ backgroundColor: coachColor(read.coach_type) }}
                        />
                        {coachLabel(read.coach_type)}
                      </span>
                    </td>
                    <td className="px-4 py-3 font-mono">{read.coach_code || "—"}</td>
                    <td className="px-4 py-3 font-mono">
                      {(read.confidence * 100).toFixed(0)}%
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </section>
  );
}

function Stat({ label, value }: { label: string; value: number }) {
  return (
    <div>
      <p className="font-display text-2xl text-mist">{value}</p>
      <p className="mt-1 text-[10px] uppercase tracking-widest text-rail">{label}</p>
    </div>
  );
}
