ALTER TABLE "User"
ADD COLUMN "accountType" TEXT NOT NULL DEFAULT 'SOLICITANTE';

UPDATE "User" u
SET "accountType" = 'ANUNCIANTE'
WHERE EXISTS (
  SELECT 1
  FROM "Post" p
  WHERE p."userId" = u."id"
    AND p."status" <> 'DELETED'
);
