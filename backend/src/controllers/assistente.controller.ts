import type { FastifyReply, FastifyRequest } from "fastify";

import {
    AssistenteError,
    assistenteService,
} from "../service/assistente.service.js";
import type { PerguntarAssistenteBody } from "../types/assistente.types.js";

const responderErro = (
    request: FastifyRequest,
    reply: FastifyReply,
    error: unknown,
) => {
    if (error instanceof AssistenteError) {
        return reply.status(error.statusCode).send({
            error: error.message,
            codigo: error.codigo,
        });
    }

    request.log.error(error);
    return reply.status(500).send({
        error: "Não foi possível consultar o assistente agora.",
        codigo: "erro_interno",
    });
};

class AssistenteController {
    capacidades = async (_request: FastifyRequest, reply: FastifyReply) =>
        reply.send(assistenteService.capacidades());

    perguntar = async (
        request: FastifyRequest<{ Body: PerguntarAssistenteBody }>,
        reply: FastifyReply,
    ) => {
        try {
            return reply.send(await assistenteService.perguntar(request.body));
        } catch (error) {
            return responderErro(request, reply, error);
        }
    };
}

export const assistenteController = new AssistenteController();
