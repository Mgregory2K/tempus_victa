-- V4: Core schema for Volume II (actions, quotes, trusted sources, user profile, trust scores, lexicon)

CREATE TABLE IF NOT EXISTS actions (
  action_id TEXT PRIMARY KEY,
  item_ref TEXT,
  actor TEXT,
  verb TEXT,
  params TEXT,
  created_at TEXT
);

CREATE TABLE IF NOT EXISTS quote_items (
  quote_id TEXT PRIMARY KEY,
  text TEXT,
  attribution TEXT,
  created_at TEXT
);

CREATE TABLE IF NOT EXISTS trusted_sources_active (
  domain TEXT PRIMARY KEY,
  trust_score REAL,
  updated_at TEXT
);

CREATE TABLE IF NOT EXISTS trusted_sources_quarantine (
  domain TEXT PRIMARY KEY,
  reason TEXT,
  flagged_at TEXT
);

CREATE TABLE IF NOT EXISTS user_profile (
  profile_id TEXT PRIMARY KEY,
  data TEXT,
  created_at TEXT,
  updated_at TEXT
);

CREATE TABLE IF NOT EXISTS trust_scores (
  subject TEXT PRIMARY KEY,
  score REAL,
  last_updated TEXT
);

CREATE TABLE IF NOT EXISTS lexicon_entries (
  phrase TEXT PRIMARY KEY,
  count INTEGER DEFAULT 0,
  last_seen TEXT,
  score REAL DEFAULT 0.0,
  metadata TEXT
);
