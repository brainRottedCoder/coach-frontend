export type JobStatus = "PENDING" | "PROCESSING" | "COMPLETED" | "FAILED";

export interface UploadResponse {
  job_id: string;
  status: string;
  filename: string;
  message: string;
}

export interface JobStatusResponse {
  job_id: string;
  status: JobStatus;
  filename: string;
  error_message?: string | null;
}

export interface LabelRead {
  track_id: number;
  raw_text: string;
  coach_type: string;
  coach_code?: string | null;
  confidence: number;
  frame_index?: number;
}

export interface CompositionEntry {
  position: number;
  track_id?: number | null;
  coach_code?: string | null;
  coach_type: string;
  confidence: number;
  frame_index?: number;
  source?: string;
  inferred?: boolean;
  inferred_from?: string[];
}

export interface TypeCountResponse {
  job_id: string;
  total_coaches: number;
  label_track_count: number;
  coach_track_count: number;
  fallback_count: number;
  type_counts: Record<string, number>;
  label_reads: LabelRead[];
  unknown_coach_tracks: number[];
  composition: CompositionEntry[];
  composition_coverage: number;
  composition_known_count: number;
  composition_coach_count: number;
  counts_match_total: boolean;
}

export type AppPhase = "idle" | "ready" | "uploading" | "processing" | "results" | "error";
