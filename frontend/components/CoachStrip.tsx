"use client";

import { motion } from "framer-motion";
import type { CompositionEntry } from "@/lib/types";
import { coachColor, coachLabel } from "@/lib/coachMeta";

type CoachStripProps = {
  composition: CompositionEntry[];
};

export function CoachStrip({ composition }: CoachStripProps) {
  if (!composition.length) {
    return (
      <p className="text-sm text-rail">
        No ordered composition available for this passage.
      </p>
    );
  }

  return (
    <div className="scrollbar-thin overflow-x-auto pb-3">
      <div className="flex min-w-min items-end gap-1.5 py-2">
        {composition.map((entry, index) => {
          const color = coachColor(entry.coach_type);
          const code = entry.coach_code || "—";
          return (
            <motion.div
              key={`${entry.position}-${entry.track_id ?? index}`}
              initial={{ opacity: 0, y: 16 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: Math.min(index * 0.03, 0.9), duration: 0.35 }}
              className="group relative flex w-14 shrink-0 flex-col items-center"
              title={`${coachLabel(entry.coach_type)} · ${code} · ${entry.source || "unknown"}`}
            >
              <span className="mb-1 font-mono text-[10px] text-rail">
                {entry.position}
              </span>
              <div
                className="relative flex h-16 w-full flex-col items-center justify-center border border-white/10"
                style={{
                  background: `linear-gradient(180deg, ${color}cc, ${color}66)`,
                }}
              >
                <span className="font-display text-sm leading-none text-white drop-shadow">
                  {code === "—" ? entry.coach_type.slice(0, 3).toUpperCase() : code}
                </span>
                {entry.inferred && (
                  <span className="absolute -right-0.5 -top-0.5 h-1.5 w-1.5 rounded-full bg-amber" />
                )}
              </div>
              <span className="mt-1 max-w-full truncate text-[9px] uppercase tracking-wide text-silver/70">
                {coachLabel(entry.coach_type).split(" ")[0]}
              </span>
            </motion.div>
          );
        })}
      </div>
      {/* Coupling rail under coaches */}
      <div className="mt-1 h-0.5 w-full bg-gradient-to-r from-transparent via-rail/50 to-transparent" />
    </div>
  );
}
