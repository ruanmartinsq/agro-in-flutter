import { FastifyInstance } from "fastify"
import { authMiddleware } from "../middlewares/auth.middleware.js"
import { propriedadesController } from "../controllers/propriedades.controller.js"
import { CreatePropertyBody, UpdatePropertyBody } from "../types/propriedades.types.js"

export async function propriedadesRoutes(app: FastifyInstance) {
    app.post<{ Body: CreatePropertyBody }>("/", { preHandler: [authMiddleware] }, propriedadesController.create)
    app.get("/", { preHandler: [authMiddleware] }, propriedadesController.findAll)
    app.get<{ Params: { id: string } }>("/:id", { preHandler: [authMiddleware] }, propriedadesController.findById)
    app.put<{ Params: { id: string }; Body: UpdatePropertyBody }>("/:id", { preHandler: [authMiddleware] }, propriedadesController.update)
    app.delete<{ Params: { id: string } }>("/:id", { preHandler: [authMiddleware] }, propriedadesController.remove)
}