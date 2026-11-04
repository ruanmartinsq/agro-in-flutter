import { FastifyReply, FastifyRequest } from "fastify";
import { financeiroService, FinanceiroError } from "../service/financeiro.service.js";
import { CreateFinanceiroBody, UpdateFinanceiroBody} from "../types/financeiro.types.js";

class FinanceiroController {
    create = async (
        request: FastifyRequest<{ Body: CreateFinanceiroBody }>,
        reply: FastifyReply
    ) => {
        try {
            const financeiro = await financeiroService.create(request.user.id, request.body);
            return reply.status(201).send(financeiro);
        } catch (error) {
            if (error instanceof FinanceiroError) {
                return reply.status(error.statusCode).send({ error: error.message });
            }

            request.log.error(error);
            return reply.status(500).send({ error: "Erro ao cadastrar lançamento financeiro." });
        }
    };

    findAll = async (request: FastifyRequest, reply: FastifyReply) => {
        try {
            const financeiros = await financeiroService.findAll(request.user.id);
            return reply.send(financeiros);
        } catch (error) {
            request.log.error(error);
            return reply.status(500).send({ error: "Erro ao buscar lançamentos financeiros." });
        }
    };

    findById = async (
        request: FastifyRequest<{ Params: { id: string } }>,
        reply: FastifyReply
    ) => {
        try {
            const financeiro = await financeiroService.findById(
                request.user.id,
                Number(request.params.id)
            );
            return reply.send(financeiro);
        } catch (error) {
            if (error instanceof FinanceiroError) {
                return reply.status(error.statusCode).send({ error: error.message });
            }

            request.log.error(error);
            return reply.status(500).send({ error: "Erro ao buscar lançamento financeiro." });
        }
    };

    update = async (
        request: FastifyRequest<{ Params:  { id: string }; Body: UpdateFinanceiroBody }>,
        reply: FastifyReply
    ) => {
        try {
            const atualizado = await financeiroService.update(
                request.user.id,
                Number(request.params.id),
                request.body
            );
            return reply.send(atualizado);
        } catch (error) {
            if (error instanceof FinanceiroError) {
                return reply.status(error.statusCode).send({ error: error.message });
            }

            request.log.error(error);
            return reply.status(500).send({ error: "Erro ao atualizar lançamento financeiro." });
        }
    };

    remove = async (
        request: FastifyRequest<{ Params: { id: string } }>,
        reply: FastifyReply
    ) => {
        try {
            await financeiroService.delete(request.user.id, Number(request.params.id));
            return reply.status(204).send();
        } catch (error) {
            if (error instanceof FinanceiroError) {
                return reply.status(error.statusCode).send({ error: error.message });
            }

            request.log.error(error);
            return reply.status(500).send({ error: "Erro ao deletar lançamento financeiro." });
        }
    };
}

export const financeiroController = new FinanceiroController();