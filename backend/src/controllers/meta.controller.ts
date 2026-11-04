import { FastifyReply, FastifyRequest } from "fastify";
import { metaService, MetaError } from "../service/meta.service.js";
import { CreateMetaBody, UpdateMetaBody } from "../types/meta.types.js";

class MetaController {

    create = async (request: FastifyRequest<{ Body: CreateMetaBody }>, reply: FastifyReply) => {
        try {
            const meta = await metaService.create(request.user.id, request.body)

            return reply.status(201).send(meta)
        } catch (error) {

            if (error instanceof MetaError) {
                return reply.status(error.statusCode).send({ error: error.message })
            }

            request.log.error(error)
            return reply.status(500).send({ error: "Erro ao criar a meta" })
        }
    }

    findAll = async (request: FastifyRequest, reply: FastifyReply) => {
        try {
            const metas = await metaService.findAll(request.user.id)

            return reply.status(200).send(metas)
        } catch (error) {

            request.log.error(error)
            return reply.status(500).send({ error: "Erro ao listar metas" })
        }
    }

    findById = async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
        try {
            const meta = await metaService.findById(request.user.id, Number(request.params.id))

            return reply.send(meta)
        } catch (error) {

            if (error instanceof MetaError) {
                return reply.status(error.statusCode).send({ error: error.message })
            }

            request.log.error(error)
            return reply.status(500).send({ error: "Erro ao obter meta" })
        }
    }

    update = async (request: FastifyRequest<{ Params: { id: string }; Body: UpdateMetaBody }>, reply: FastifyReply) => {
        try {
            const atualizada = await metaService.update(request.user.id, Number(request.params.id),request.body)

            return reply.send(atualizada)
        } catch (error) {

            if (error instanceof MetaError) {
                return reply.status(error.statusCode).send({ error: error.message })
            }

            request.log.error(error)
            return reply.status(500).send({ error: "Erro ao atualizar a meta" })
        }
    };

    remove = async (request: FastifyRequest<{ Params: { id: string } }>, reply: FastifyReply) => {
        try {
            await metaService.delete(request.user.id, Number(request.params.id))

            return reply.status(204).send()
        } catch (error) {

            if (error instanceof MetaError) {
                return reply.status(error.statusCode).send({ error: error.message })
            }

            request.log.error(error)
            return reply.status(500).send({ error: "Erro ao deletar a meta" })
        }
    }
}

export const metaController = new MetaController()