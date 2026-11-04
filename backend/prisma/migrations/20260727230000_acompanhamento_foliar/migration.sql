CREATE TABLE "CasoFoliar" (
    "id" SERIAL NOT NULL,
    "usuario_id" INTEGER NOT NULL,
    "propriedade_id" INTEGER,
    "titulo" TEXT NOT NULL,
    "cultura" TEXT,
    "tratamento" TEXT,
    "status" TEXT NOT NULL DEFAULT 'em_quarentena',
    "proxima_revisao_em" TIMESTAMP(3),
    "encerrado_em" TIMESTAMP(3),
    "criado_em" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "atualizado_em" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "CasoFoliar_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "VistoriaArea" (
    "id" SERIAL NOT NULL,
    "usuario_id" INTEGER NOT NULL,
    "propriedade_id" INTEGER,
    "nome" TEXT NOT NULL,
    "cultura" TEXT,
    "objetivo" TEXT,
    "status" TEXT NOT NULL DEFAULT 'em_andamento',
    "concluido_em" TIMESTAMP(3),
    "criado_em" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "atualizado_em" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "VistoriaArea_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "PontoVistoria" (
    "id" SERIAL NOT NULL,
    "vistoria_id" INTEGER NOT NULL,
    "nome" TEXT NOT NULL,
    "setor" TEXT,
    "ordem" INTEGER NOT NULL,
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "precisao_metros" DOUBLE PRECISION,
    "criado_em" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "atualizado_em" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "PontoVistoria_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "AnaliseFoliar"
ADD COLUMN "caso_id" INTEGER,
ADD COLUMN "ponto_vistoria_id" INTEGER,
ADD COLUMN "etapa_acompanhamento" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN "comparacao_anterior" JSONB;

CREATE INDEX "CasoFoliar_usuario_id_status_criado_em_idx"
ON "CasoFoliar"("usuario_id", "status", "criado_em");
CREATE INDEX "CasoFoliar_propriedade_id_idx"
ON "CasoFoliar"("propriedade_id");
CREATE INDEX "VistoriaArea_usuario_id_status_criado_em_idx"
ON "VistoriaArea"("usuario_id", "status", "criado_em");
CREATE INDEX "VistoriaArea_propriedade_id_idx"
ON "VistoriaArea"("propriedade_id");
CREATE INDEX "PontoVistoria_vistoria_id_ordem_idx"
ON "PontoVistoria"("vistoria_id", "ordem");
CREATE INDEX "AnaliseFoliar_caso_id_criado_em_idx"
ON "AnaliseFoliar"("caso_id", "criado_em");
CREATE INDEX "AnaliseFoliar_ponto_vistoria_id_criado_em_idx"
ON "AnaliseFoliar"("ponto_vistoria_id", "criado_em");

ALTER TABLE "CasoFoliar"
ADD CONSTRAINT "CasoFoliar_usuario_id_fkey"
FOREIGN KEY ("usuario_id") REFERENCES "Usuario"("id")
ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CasoFoliar"
ADD CONSTRAINT "CasoFoliar_propriedade_id_fkey"
FOREIGN KEY ("propriedade_id") REFERENCES "Propriedade"("id")
ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "VistoriaArea"
ADD CONSTRAINT "VistoriaArea_usuario_id_fkey"
FOREIGN KEY ("usuario_id") REFERENCES "Usuario"("id")
ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "VistoriaArea"
ADD CONSTRAINT "VistoriaArea_propriedade_id_fkey"
FOREIGN KEY ("propriedade_id") REFERENCES "Propriedade"("id")
ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "PontoVistoria"
ADD CONSTRAINT "PontoVistoria_vistoria_id_fkey"
FOREIGN KEY ("vistoria_id") REFERENCES "VistoriaArea"("id")
ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "AnaliseFoliar"
ADD CONSTRAINT "AnaliseFoliar_caso_id_fkey"
FOREIGN KEY ("caso_id") REFERENCES "CasoFoliar"("id")
ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "AnaliseFoliar"
ADD CONSTRAINT "AnaliseFoliar_ponto_vistoria_id_fkey"
FOREIGN KEY ("ponto_vistoria_id") REFERENCES "PontoVistoria"("id")
ON DELETE SET NULL ON UPDATE CASCADE;
