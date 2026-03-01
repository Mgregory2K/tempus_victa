-- V2: create drafts table for AskUser inline edits/autosave
CREATE TABLE IF NOT EXISTS drafts (
  prov_id TEXT PRIMARY KEY,
  overrides TEXT,
  updated_at TEXT
);
