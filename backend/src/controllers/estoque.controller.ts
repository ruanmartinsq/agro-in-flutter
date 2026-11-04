import { FastifyReply, FastifyRequest } from "fastify"
import { estoqueService, EstoqueError } from "../service/estoque.service.js"
import { CreateEstoqueBody, UpdateEstoqueBody } from "../types/estoque.types.js"

class EstoqueController {
    create = async (request: FastifyRequest<{ Body: CreateEstoqueBody }>, reply: FastifyReply) => {
        try {
            const estoque = await estoqueService.create(request.user.id, request.body)

            return reply.status(201).send(estoque)
        } catch (error) {

            if (error instanceof EstoqueError) {
                return reply.status(error.statusCode).send({ error: error.message })
            }

            request.log.error(error)
            return reply.status(500).send({ error: "Erro ao cadastrar o estoque" })
        }
    }

    findAll = async (request: FastifyRequest, reply: FastifyReply) => {
        try {
            const estoques = await estoqueService.findAll(request.user.id)

            return reply.status(200).send(estoques)
        } catch (error) {

            request.log.error(error)
            return reply.status(500).send({ error: "Erro ao listar estoque" })
        }
    };

    findById = async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
        try {
            const estoque = await estoqueService.findById(request.user.id, Number(request.params.id))

            return reply.send(estoque)
        } catch (error) {

            if (error instanceof EstoqueError) {
                return reply.status(error.statusCode).send({ error: error.message })
            }

            request.log.error(error)
            return reply.status(500).send({ error: "Erro ao obter estoque" })
        }
    };

    update = async (request: FastifyRequest<{ Params: { id: string }; Body: UpdateEstoqueBody }>, reply: FastifyReply) => {
        try {
            const atualizado = await estoqueService.update(request.user.id, Number(request.params.id), request.body)

            return reply.send(atualizado)
        } catch (error) {

            if (error instanceof EstoqueError) {
                return reply.status(error.statusCode).send({ error: error.message })
            }

            request.log.error(error)
            return reply.status(500).send({ error: "Erro ao atualizar o estoque" })
        }
    }

    remove = async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
        try {
            await estoqueService.delete(request.user.id, Number(request.params.id))

            return reply.status(204).send()
        } catch (error) {

            if (error instanceof EstoqueError) {
                return reply.status(error.statusCode).send({ error: error.message })
            }

            request.log.error(error)
            return reply.status(500).send({ error: "Erro ao deletar o estoque" })
        }
    }
}

export const estoqueController = new EstoqueController()