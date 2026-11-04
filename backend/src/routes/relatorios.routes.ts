import { FastifyInstance } from "fastify";
import { relatorioController } from "../controllers/relatorios.controller.js"
import { authMiddleware } from "../middlewares/auth.middleware.js";

export async function relatoriosRoutes(app: FastifyInstance) {
    app.get<{ Params: { propriedadeId: string }}>("/:propriedadeId", { preHandler: [authMiddleware] }, relatorioController.gerar)
}