ALTER TABLE "PostMedia" ALTER COLUMN "data" DROP NOT NULL;

ALTER TABLE "PostMedia"
ADD COLUMN "storageDriver" TEXT NOT NULL DEFAULT 'DATABASE',
ADD COLUMN "storageKey" TEXT;

CREATE UNIQUE INDEX "PostMedia_storageKey_key" ON "PostMedia"("storageKey");
