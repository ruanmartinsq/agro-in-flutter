import { FastifyInstance } from "fastify";
import { authMiddleware } from "../middlewares/auth.middleware.js"
import { CreateFinanceiroBody, UpdateFinanceiroBody } from "../types/financeiro.types.js"
import { financeiroController } from "../controllers/financeiro.controller.js";

export const financeiroRoutes = async (app: FastifyInstance) => {
    app.post<{ Body: CreateFinanceiroBody }>("/", { preHandler: [authMiddleware] }, financeiroController.create )
    app.get("/", { preHandler: [authMiddleware] }, financeiroController.findAll)
    app.get<{ Params: {id: string} }>("/:id", { preHandler: [authMiddleware] } , financeiroController.findById)
    app.put<{ Params: {id: string}, Body: UpdateFinanceiroBody }>("/:id", { preHandler: [authMiddleware] }, financeiroController.update)
    app.delete<{ Params: {id: string} }>("/:id", { preHandler: [authMiddleware] } , financeiroController.remove)
}
