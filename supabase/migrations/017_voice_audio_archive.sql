-- Temporary audio archive for tuning the voice-to-tasks pipeline.
-- Clips are stored by the edge function (service role) in a private bucket;
-- voice_transcripts.audio_path points at them. Remove bucket + column when done.

ALTER TABLE voice_transcripts ADD COLUMN IF NOT EXISTS audio_path TEXT;

INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('voice-audio', 'voice-audio', false, 26214400)
ON CONFLICT (id) DO NOTHING;
