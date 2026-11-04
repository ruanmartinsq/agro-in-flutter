import { FastifyInstance } from "fastify"
import { metaController } from "../controllers/meta.controller.js"
import { CreateMetaBody, UpdateMetaBody } from "../types/meta.types.js"
import { authMiddleware } from "../middlewares/auth.middleware.js"

export const metaRoutes = (app: FastifyInstance) => {
    app.post<{ Body: CreateMetaBody }>("/", {preHandler: [authMiddleware]}, metaController.create)
    app.get("/", {preHandler: [authMiddleware]}, metaController.findAll)
    app.get<{ Params: {id: string} }>("/:id", {preHandler: [authMiddleware]}, metaController.findById)
    app.put<{ Params: {id: string}, Body: UpdateMetaBody }>("/:id", {preHandler: [authMiddleware]}, metaController.update)
    app.delete<{ Params: {id: string} }>("/:id", {preHandler: [authMiddleware]}, metaController.remove)
}
