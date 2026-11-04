import { FastifyReply, FastifyRequest } from "fastify";
import { propriedadesService, PropriedadeError } from "../service/propriedades.service.js";
import { CreatePropertyBody, UpdatePropertyBody } from "../types/propriedades.types.js";

class PropriedadesController {
    create = async (request: FastifyRequest<{ Body: CreatePropertyBody }>, reply: FastifyReply) => {
        try {
            const propriedade = await propriedadesService.create(request.user.id, request.body)

            return reply.status(201).send(propriedade)
        } catch (error) {

            request.log.error(error)
            return reply.status(500).send({ error: "Erro ao cadastrar propriedade." })
        }
    }

    findAll = async (request: FastifyRequest, reply: FastifyReply) => {
        try {
            const propriedades = await propriedadesService.findAll(request.user.id)

            return reply.send(propriedades)
        } catch (error) {

            request.log.error(error)
            return reply.status(500).send({ error: "Erro ao buscar propriedades." })
        }
    }

    findById = async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
        try {
            const propriedade = await propriedadesService.findById(request.user.id, Number(request.params.id))

            return reply.send(propriedade)
        } catch (error) {

            if (error instanceof PropriedadeError) {
                return reply.status(error.statusCode).send({ error: error.message })
            }

            request.log.error(error)
            return reply.status(500).send({ error: "Erro ao buscar propriedade." })
        }
    }

    update = async (request: FastifyRequest<{ Params: { id: string }; Body: UpdatePropertyBody }>, reply: FastifyReply) => {
        try {
            const atualizada = await propriedadesService.update(request.user.id, Number(request.params.id), request.body)

            return reply.send(atualizada)
        } catch (error) {

            if (error instanceof PropriedadeError) {
                return reply.status(error.statusCode).send({ error: error.message })
            }

            request.log.error(error);
            return reply.status(500).send({ error: "Erro ao atualizar propriedade." })
        }
    }

    remove = async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
        try {
            await propriedadesService.delete(request.user.id, Number(request.params.id))

            return reply.status(204).send()
        } catch (error) {

            if (error instanceof PropriedadeError) {
                return reply.status(error.statusCode).send({ error: error.message })
            }

            request.log.error(error)
            return reply.status(500).send({ error: "Erro ao deletar propriedade." })
        }
    }
}

export const propriedadesController = new PropriedadesController()