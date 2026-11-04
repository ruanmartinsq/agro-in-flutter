
import { FastifyInstance } from "fastify"
import { producaoController } from "../controllers/producao.controller.js"
import { CreateProducaoBody, UpdateProducaoBody } from "../types/producao.types.js"
import { authMiddleware } from "../middlewares/auth.middleware.js"

export const producaoRoutes = async (app: FastifyInstance) => {
    app.post<{ Body: CreateProducaoBody }>("/", { preHandler: [authMiddleware] } ,producaoController.create)
    app.get("/", { preHandler: [authMiddleware] } ,producaoController.findAll)
    app.get<{Params: {id: string}}>("/:id", { preHandler: [authMiddleware] } ,producaoController.findById)
    app.put<{Params: {id: string}, Body: UpdateProducaoBody}>("/:id", { preHandler: [authMiddleware] } ,producaoController.update)
    app.delete<{Params: {id: string}}>("/:id", { preHandler: [authMiddleware] } ,producaoController.remove)
}