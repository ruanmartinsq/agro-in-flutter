-- CreateTable
CREATE TABLE "SenhaResetToken" (
    "id" SERIAL NOT NULL,
    "usuario_id" INTEGER NOT NULL,
    "token_hash" TEXT NOT NULL,
    "expira_em" TIMESTAMP(3) NOT NULL,
    "usado_em" TIMESTAMP(3),
    "criado_em" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "SenhaResetToken_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "SenhaResetToken_token_hash_key" ON "SenhaResetToken"("token_hash");

-- CreateIndex
CREATE INDEX "SenhaResetToken_usuario_id_idx" ON "SenhaResetToken"("usuario_id");

-- CreateIndex
CREATE INDEX "SenhaResetToken_expira_em_idx" ON "SenhaResetToken"("expira_em");

-- AddForeignKey
ALTER TABLE "SenhaResetToken"
ADD CONSTRAINT "SenhaResetToken_usuario_id_fkey"
FOREIGN KEY ("usuario_id") REFERENCES "Usuario"("id")
ON DELETE CASCADE ON UPDATE CASCADE;
