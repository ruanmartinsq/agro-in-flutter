import { FastifyInstance } from "fastify"
import { CreateEstoqueBody, UpdateEstoqueBody } from "../types/estoque.types.js"
import { estoqueController } from "../controllers/estoque.controller.js"
import { authMiddleware } from "../middlewares/auth.middleware.js"

export const estoqueRoutes = async (app: FastifyInstance) => {
    app.post<{ Body: CreateEstoqueBody }>("/", { preHandler: [authMiddleware]}, estoqueController.create)
    app.get("/", { preHandler: [authMiddleware]}, estoqueController.findAll)
    app.get<{ Params: { id: string } }>("/:id", { preHandler: [authMiddleware]}, estoqueController.findById)
    app.put<{ Params: { id: string }, Body: UpdateEstoqueBody }>("/:id", { preHandler: [authMiddleware]}, estoqueController.update)
    app.delete<{ Params: { id: string } }>("/:id", { preHandler: [authMiddleware]}, estoqueController.remove)
}
