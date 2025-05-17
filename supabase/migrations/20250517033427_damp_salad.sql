/*
  # Add status column to payment_methods table

  1. Changes
    - Add `status` column to `payment_methods` table with type TEXT
    - Add check constraint to ensure valid status values
    - Set default value to 'active'
    - Add index on status column for better query performance

  2. Validation
    - Check constraint ensures only 'active' or 'inactive' values
*/

-- Add status column with default value and constraint
ALTER TABLE payment_methods 
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active' NOT NULL;

-- Add check constraint for valid status values
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint 
    WHERE conname = 'payment_methods_status_check'
  ) THEN
    ALTER TABLE payment_methods
    ADD CONSTRAINT payment_methods_status_check 
    CHECK (status IN ('active', 'inactive'));
  END IF;
END $$;

-- Create index on status column
CREATE INDEX IF NOT EXISTS idx_payment_methods_status 
ON payment_methods(status);

-- Update any existing rows to have 'active' status if null
UPDATE payment_methods 
SET status = 'active' 
WHERE status IS NULL;