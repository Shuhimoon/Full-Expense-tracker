ALTER TABLE books ADD COLUMN IF NOT EXISTS opening_locked boolean NOT NULL DEFAULT false;
UPDATE books SET opening_locked = true WHERE opening_date IS NOT NULL;
