-- Backfill any null job amounts using the linked service price or a safe fallback
UPDATE "Job" j
SET amount = COALESCE(j.amount, s.price, 1.00)
FROM "Service" s
WHERE s.id = j."serviceId";

-- Ensure no nulls remain before altering the column constraint
UPDATE "Job" SET amount = 1.00 WHERE amount IS NULL;

ALTER TABLE "Job" ALTER COLUMN amount SET NOT NULL;
