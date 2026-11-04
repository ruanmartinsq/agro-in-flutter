import { FastifyReply, FastifyRequest } from "fastify"
import { producaoService, ProducaoError } from "../service/producao.service.js"
import { CreateProducaoBody, UpdateProducaoBody } from "../types/producao.types.js"

class ProducaoController {

    create = async (request: FastifyRequest<{ Body: CreateProducaoBody }>, reply: FastifyReply) => {
        try {
            const producao = await producaoService.create(request.user.id, request.body)

            return reply.status(201).send(producao)
        } catch (error) {

            if (error instanceof ProducaoError) {
                return reply.status(error.statusCode).send({ error: error.message })
            }

            request.log.error(error)
            return reply.status(500).send({ error: "Erro ao cadastrar produção" })
        }
    }

    findAll = async (request: FastifyRequest, reply: FastifyReply) => {
        try {
            const producoes = await producaoService.findAll(request.user.id)

            return reply.status(200).send(producoes)
        } catch (error) {
            request.log.error(error)

            return reply.status(500).send({ error: "Erro ao listar produções" })
        }
    }

    findById = async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
        try {
            const producao = await producaoService.findById( request.user.id, Number(request.params.id) )

            return reply.status(200).send(producao)
        } catch (error) {

            if (error instanceof ProducaoError) {
                return reply.status(error.statusCode).send({ error: error.message })
            }

            request.log.error(error)
            return reply.status(500).send({ error: "Erro ao obter produção" })
        }
    }

    update = async (request: FastifyRequest<{ Params: { id: string }; Body: UpdateProducaoBody }>, reply: FastifyReply) => {
        try {
            const atualizada = await producaoService.update( request.user.id, Number(request.params.id), request.body)

            return reply.status(200).send(atualizada);
        } catch (error) {

            if (error instanceof ProducaoError) {
                return reply.status(error.statusCode).send({ error: error.message })
            }

            request.log.error(error)
            return reply.status(500).send({ error: "Erro ao atualizar produção" })
        }
    }

    remove = async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
        try {
            await producaoService.delete(request.user.id, Number(request.params.id))

            return reply.status(204).send()
        } catch (error) {

            if (error instanceof ProducaoError) {
                return reply.status(error.statusCode).send({ error: error.message })
            }

            request.log.error(error)
            return reply.status(500).send({ error: "Erro ao deletar produção" })
        }
    }
}

export const producaoController = new ProducaoController();