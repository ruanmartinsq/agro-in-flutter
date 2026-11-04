import type { FastifyInstance } from "fastify";

import { assistenteController } from "../controllers/assistente.controller.js";
import { authMiddleware } from "../middlewares/auth.middleware.js";
import type { PerguntarAssistenteBody } from "../types/assistente.types.js";

export const assistenteRoutes = async (app: FastifyInstance) => {
    app.get(
        "/capacidades",
        { preHandler: [authMiddleware] },
        assistenteController.capacidades,
    );
    app.post<{ Body: PerguntarAssistenteBody }>(
        "/perguntar",
        { preHandler: [authMiddleware] },
        assistenteController.perguntar,
    );
};
