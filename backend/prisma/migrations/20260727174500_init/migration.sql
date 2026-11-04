-- CreateEnum
CREATE TYPE "TipoFinanceiro" AS ENUM ('entrada', 'saida');

-- CreateTable
CREATE TABLE "Usuario" (
    "id" SERIAL NOT NULL,
    "nome" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "senha_hash" TEXT NOT NULL,
    "criado_em" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Usuario_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Propriedade" (
    "id" SERIAL NOT NULL,
    "usuario_id" INTEGER NOT NULL,
    "nome" TEXT NOT NULL,
    "area_total" DOUBLE PRECISION,
    "tipo_producao" TEXT,
    "localizacao" TEXT,
    "criado_em" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Propriedade_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Financeiro" (
    "id" SERIAL NOT NULL,
    "propriedade_id" INTEGER NOT NULL,
    "tipo" "TipoFinanceiro" NOT NULL,
    "categoria" TEXT,
    "descricao" TEXT,
    "valor" DOUBLE PRECISION NOT NULL,
    "data" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Financeiro_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Producao" (
    "id" SERIAL NOT NULL,
    "propriedade_id" INTEGER NOT NULL,
    "tipo" TEXT NOT NULL,
    "area_utilizada" DOUBLE PRECISION,
    "quantidade" DOUBLE PRECISION,
    "data_inicio" TIMESTAMP(3),
    "data_fim" TIMESTAMP(3),
    "status" TEXT,

    CONSTRAINT "Producao_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Estoque" (
    "id" SERIAL NOT NULL,
    "propriedade_id" INTEGER NOT NULL,
    "item" TEXT NOT NULL,
    "categoria" TEXT,
    "quantidade" DOUBLE PRECISION NOT NULL,
    "unidade" TEXT,
    "quantidade_minima" DOUBLE PRECISION,

    CONSTRAINT "Estoque_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Meta" (
    "id" SERIAL NOT NULL,
    "propriedade_id" INTEGER NOT NULL,
    "descricao" TEXT NOT NULL,
    "categoria" TEXT DEFAULT 'geral',
    "valor_alvo" DOUBLE PRECISION,
    "valor_atual" DOUBLE PRECISION DEFAULT 0,
    "unidade" TEXT,
    "responsavel" TEXT,
    "prazo" TIMESTAMP(3),
    "status" TEXT DEFAULT 'pendente',

    CONSTRAINT "Meta_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Usuario_email_key" ON "Usuario"("email");

-- AddForeignKey
ALTER TABLE "Propriedade"
ADD CONSTRAINT "Propriedade_usuario_id_fkey"
FOREIGN KEY ("usuario_id") REFERENCES "Usuario"("id")
ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Financeiro"
ADD CONSTRAINT "Financeiro_propriedade_id_fkey"
FOREIGN KEY ("propriedade_id") REFERENCES "Propriedade"("id")
ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Producao"
ADD CONSTRAINT "Producao_propriedade_id_fkey"
FOREIGN KEY ("propriedade_id") REFERENCES "Propriedade"("id")
ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Estoque"
ADD CONSTRAINT "Estoque_propriedade_id_fkey"
FOREIGN KEY ("propriedade_id") REFERENCES "Propriedade"("id")
ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Meta"
ADD CONSTRAINT "Meta_propriedade_id_fkey"
FOREIGN KEY ("propriedade_id") REFERENCES "Propriedade"("id")
ON DELETE RESTRICT ON UPDATE CASCADE;
