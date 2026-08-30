-- Auto-delete archived voice clips older than 30 days (pg_cron, daily 03:15 UTC).
-- Deleting the storage.objects row removes the file from the bucket.

CREATE EXTENSION IF NOT EXISTS pg_cron;

CREATE OR REPLACE FUNCTION public.purge_old_voice_audio()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, storage
AS $$
BEGIN
  DELETE FROM storage.objects
   WHERE bucket_id = 'voice-audio'
     AND created_at < now() - interval '30 days';
  UPDATE public.voice_transcripts
     SET audio_path = NULL
   WHERE audio_path IS NOT NULL
     AND created_at < now() - interval '30 days';
END;
$$;

SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname = 'purge_old_voice_audio';
SELECT cron.schedule('purge_old_voice_audio', '15 3 * * *', $$SELECT public.purge_old_voice_audio()$$);
