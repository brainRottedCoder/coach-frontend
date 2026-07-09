export const COACH_TYPE_ORDER = [
  "engine",
  "power",
  "ac_1tier",
  "ac_2tier",
  "ac_3tier",
  "sleeper",
  "general",
  "unknown",
] as const;

export type CoachTypeKey = (typeof COACH_TYPE_ORDER)[number] | string;

export const COACH_LABELS: Record<string, string> = {
  engine: "Locomotive",
  power: "Power / EOG",
  ac_1tier: "AC 1st Tier",
  ac_2tier: "AC 2nd Tier",
  ac_3tier: "AC 3rd Tier",
  sleeper: "Sleeper",
  general: "General",
  unknown: "Unknown",
};

export const COACH_COLORS: Record<string, string> = {
  engine: "#C41E3A",
  power: "#E8A317",
  ac_1tier: "#5B8DEF",
  ac_2tier: "#3D9B8F",
  ac_3tier: "#6B9AC4",
  sleeper: "#A67C52",
  general: "#8B95A8",
  unknown: "#4A5568",
};

export function coachLabel(type: string): string {
  return COACH_LABELS[type] || type.replace(/_/g, " ");
}

export function coachColor(type: string): string {
  return COACH_COLORS[type] || COACH_COLORS.unknown;
}

export const ALLOWED_EXTENSIONS = [".mp4", ".avi", ".mov", ".mkv"];

export function isAllowedVideo(file: File): boolean {
  const name = file.name.toLowerCase();
  return ALLOWED_EXTENSIONS.some((ext) => name.endsWith(ext));
}
