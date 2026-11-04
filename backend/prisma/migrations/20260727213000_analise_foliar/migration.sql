CREATE TABLE "AnaliseFoliar" (
    "id" SERIAL NOT NULL,
    "usuario_id" INTEGER NOT NULL,
    "propriedade_id" INTEGER,
    "cultura_informada" TEXT,
    "cultura_detectada" TEXT,
    "cultura_cientifica" TEXT,
    "cultura_confianca" DOUBLE PRECISION,
    "status_geral" TEXT NOT NULL,
    "confianca" DOUBLE PRECISION,
    "origem_diagnostico" TEXT NOT NULL,
    "referencia_provedor" TEXT,
    "versao_modelo" TEXT,
    "qualidade_foto" TEXT NOT NULL,
    "is_planta" DOUBLE PRECISION,
    "hipoteses" JSONB NOT NULL,
    "recomendacoes" JSONB NOT NULL,
    "perguntas_confirmacao" JSONB NOT NULL,
    "metricas_visuais" JSONB NOT NULL,
    "avisos" JSONB NOT NULL,
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "observacoes" TEXT,
    "feedback_util" BOOLEAN,
    "diagnostico_confirmado" TEXT,
    "imagem_preview" BYTEA NOT NULL,
    "imagem_mime" TEXT NOT NULL DEFAULT 'image/jpeg',
    "criado_em" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "atualizado_em" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AnaliseFoliar_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "AnaliseFoliar_usuario_id_criado_em_idx"
ON "AnaliseFoliar"("usuario_id", "criado_em");

CREATE INDEX "AnaliseFoliar_propriedade_id_idx"
ON "AnaliseFoliar"("propriedade_id");

ALTER TABLE "AnaliseFoliar"
ADD CONSTRAINT "AnaliseFoliar_usuario_id_fkey"
FOREIGN KEY ("usuario_id") REFERENCES "Usuario"("id")
ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "AnaliseFoliar"
ADD CONSTRAINT "AnaliseFoliar_propriedade_id_fkey"
FOREIGN KEY ("propriedade_id") REFERENCES "Propriedade"("id")
ON DELETE SET NULL ON UPDATE CASCADE;
