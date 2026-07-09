"use client";

import { motion } from "framer-motion";

type HeroProps = {
  onUploadClick: () => void;
};

export function Hero({ onUploadClick }: HeroProps) {
  return (
    <section className="relative flex min-h-[100dvh] flex-col justify-end overflow-hidden pb-16 pt-24 md:justify-center md:pb-24 md:pt-20">
      <div className="pointer-events-none absolute inset-0 rail-tracks opacity-70" />

      {/* Horizon line / platform silhouette */}
      <div
        className="pointer-events-none absolute inset-x-0 bottom-0 h-40"
        style={{
          background:
            "linear-gradient(180deg, transparent, rgba(11,18,32,0.9) 40%, #0b1220), repeating-linear-gradient(90deg, transparent 0 18px, rgba(139,149,168,0.2) 18px 20px)",
        }}
      />

      <div className="relative z-10 mx-auto w-full max-w-5xl px-6">
        <motion.p
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5 }}
          className="mb-4 text-xs font-medium uppercase tracking-[0.35em] text-amber"
        >
          Indian Railways · Side-view ATCR
        </motion.p>

        <motion.h1
          initial={{ opacity: 0, y: 24 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.7, delay: 0.08 }}
          className="font-display text-[clamp(4.5rem,18vw,9.5rem)] leading-[0.85] tracking-tight text-mist"
        >
          ATCR
        </motion.h1>

        <motion.p
          initial={{ opacity: 0, y: 16 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6, delay: 0.2 }}
          className="mt-4 max-w-md text-lg text-silver/90 md:text-xl"
        >
          Automatic Train Composition Recognition — count coaches and read their
          types from station footage.
        </motion.p>

        <motion.div
          initial={{ opacity: 0, y: 12 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.5, delay: 0.35 }}
          className="mt-10 flex flex-wrap items-center gap-4"
        >
          <button
            type="button"
            onClick={onUploadClick}
            className="group relative overflow-hidden bg-crimson px-8 py-3.5 text-sm font-semibold uppercase tracking-widest text-white transition hover:brightness-110"
          >
            <span className="relative z-10">Upload footage</span>
            <span className="absolute inset-0 -translate-x-full bg-amber/30 transition duration-500 group-hover:translate-x-0" />
          </button>
          <span className="text-sm text-rail">
            MP4 · AVI · MOV · MKV
          </span>
        </motion.div>
      </div>

      {/* Moving signal light */}
      <motion.div
        aria-hidden
        className="pointer-events-none absolute right-[12%] top-[28%] h-3 w-3 rounded-full bg-amber"
        animate={{ opacity: [0.35, 1, 0.35], scale: [1, 1.25, 1] }}
        transition={{ duration: 2.4, repeat: Infinity, ease: "easeInOut" }}
        style={{ boxShadow: "0 0 24px 6px rgba(232,163,23,0.55)" }}
      />
    </section>
  );
}
