-- 2026-10-20: opening lock removed; a created book is enough to record.
UPDATE books SET opening_date = (created_at AT TIME ZONE 'Asia/Taipei')::date WHERE opening_date IS NULL;
ALTER TABLE books DROP COLUMN IF EXISTS opening_locked;
