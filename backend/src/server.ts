import Fastify from "fastify";
import cors from "@fastify/cors";
import "dotenv/config";

import { prisma } from "./lib/prisma.js";
import { authRoutes } from "./routes/auth.routes.js";
import { propriedadesRoutes } from "./routes/propriedades.routes.js";
import { financeiroRoutes } from "./routes/financeiro.routes.js";
import { producaoRoutes } from "./routes/producao.routes.js";
import { estoqueRoutes } from "./routes/estoque.routes.js";
import { metaRoutes } from "./routes/meta.routes.js";
import { relatoriosRoutes } from "./routes/relatorios.routes.js";
import { analiseFoliarRoutes } from "./routes/analise-foliar.routes.js";
import { assistenteRoutes } from "./routes/assistente.routes.js";



const app = Fastify({
    logger: true,
    bodyLimit: 9 * 1024 * 1024,
});

const port = 3333;

app.get("/", async () => {
    return {
        msg: "AGRO.IN API"
    };
});

app.get("/health", async () => {
    await prisma.$queryRaw`SELECT 1`;

    return {
        status: "ok",
        database: "connected",
    };
});

const start = async () => {
    await app.register(cors, {
        origin: true,
        methods: ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    });

    // Rotas de autenticação
    await app.register(authRoutes, {
        prefix: "/auth",
    });

    // Rotas de propriedades
    await app.register(propriedadesRoutes, {
        prefix: "/propriedades",
    });

    // Rotas financeiras
    await app.register(financeiroRoutes, {
        prefix: "/financeiro",
    });

    // Rotas de produção
    await app.register(producaoRoutes, {
        prefix: "/producao",
    });

    // Rotas de estoque
    await app.register(estoqueRoutes, {
        prefix: "/estoque",
    });

    // Rotas de metas
    await app.register(metaRoutes, {
        prefix: "/metas"
    });

    // Rotas de relatórios
    await app.register(relatoriosRoutes, {
        prefix: "/relatorios",
    });

    // Triagem e histórico de análise foliar
    await app.register(analiseFoliarRoutes, {
        prefix: "/analise-foliar",
    });

    // Orientação agronômica com RAG e provedor gratuito
    await app.register(assistenteRoutes, {
        prefix: "/assistente",
    });

    await app.listen({
        port,
        host: "0.0.0.0",
    });

    console.log(`Servidor rodando em http://localhost:${port}`);
};

start().catch((error) => {
    app.log.error(error);
    process.exit(1);
});
